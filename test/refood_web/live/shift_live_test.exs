defmodule RefoodWeb.ShiftLiveTest do
  use RefoodWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Refood.AccountsFixtures
  import Refood.Factory

  alias Refood.Families.Family
  alias Refood.Families.Swap
  alias Refood.Repo

  @all_weekdays [:monday, :tuesday, :wednesday, :thursday, :friday, :saturday, :sunday]

  setup %{conn: conn} do
    %{conn: log_in_user(conn, user_fixture()), yesterday: Date.add(Date.utc_today(), -1)}
  end

  defp go_to_yesterday(lv) do
    lv |> element("button[phx-click=prev-date]") |> render_click()
  end

  defp open_family(lv, family) do
    lv
    |> element("#shift-list button[phx-value-family_id=\"#{family.id}\"]")
    |> render_click()
  end

  defp click_action(lv, text) do
    lv |> element("#family-actions a", text) |> render_click()
  end

  describe "adding a swap from a past shift date" do
    test "shows 'Trocar dia' when viewing a past date", %{conn: conn} do
      family = insert(:family, status: :active, weekdays: @all_weekdays)

      {:ok, lv, _html} = live(conn, ~p"/shift")

      go_to_yesterday(lv)

      html = open_family(lv, family)

      assert html =~ "Trocar dia"
      assert html =~ "/shift/#{family.id}?new-swap"
    end

    test "creates a swap out of the past date", %{conn: conn, yesterday: yesterday} do
      family = insert(:family, status: :active, weekdays: @all_weekdays)
      target = Date.add(Date.utc_today(), 3)

      {:ok, lv, _html} = live(conn, ~p"/shift")
      go_to_yesterday(lv)

      open_family(lv, family)
      click_action(lv, "Trocar dia")

      html =
        lv
        |> form("#add-swap-form", swap: %{to: Date.to_iso8601(target)})
        |> render_submit()

      assert html =~ "Troca efetuada!"

      assert %Swap{from: ^yesterday, to: ^target} = Repo.get_by!(Swap, family_id: family.id)
    end

    test "still rejects swapping to a past date", %{conn: conn, yesterday: yesterday} do
      family = insert(:family, status: :active, weekdays: @all_weekdays)

      {:ok, lv, _html} = live(conn, ~p"/shift")
      go_to_yesterday(lv)

      open_family(lv, family)
      click_action(lv, "Trocar dia")

      html =
        lv
        |> form("#add-swap-form", swap: %{to: Date.to_iso8601(yesterday)})
        |> render_submit()

      assert html =~ "não é possível trocar para o passado"
      refute Repo.get_by(Swap, family_id: family.id)
    end
  end

  describe "page actions" do
    test "creating a help request is not offered here", %{conn: conn} do
      # It lives on Lista de Espera, which owns the queue.
      {:ok, _lv, html} = live(conn, ~p"/shift")

      refute html =~ "Criar pedido de ajuda"
      assert html =~ "Modo TV"
    end
  end

  describe "the date in the URL" do
    test "mounts on the date given, not today", %{conn: conn, yesterday: yesterday} do
      family =
        insert(:family, status: :active, weekdays: [Family.weekday_from_date(yesterday)])

      {:ok, _lv, html} = live(conn, ~p"/shift?date=#{Date.to_iso8601(yesterday)}")

      assert html =~ "F-#{family.number}"
      refute html =~ "(Hoje)"
    end

    test "survives a reload after stepping the day", %{conn: conn, yesterday: yesterday} do
      {:ok, lv, _html} = live(conn, ~p"/shift")

      go_to_yesterday(lv)

      assert assert_patch(lv) =~ "date=#{Date.to_iso8601(yesterday)}"
    end

    test "falls back to today when the date is unparseable", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/shift?date=not-a-date")

      assert html =~ "(Hoje)"
    end
  end

  describe "the TV board" do
    test "drops the app chrome", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/shift/tv")

      # The sidebar and the page title both live in the app layout the board
      # does not use, so neither should appear anywhere in the document.
      refute html =~ "Lista de Espera"
      refute html =~ "Turno"

      assert html =~ "Modo TV"
    end

    test "shows families and keeps them openable", %{conn: conn} do
      family = insert(:family, status: :active, weekdays: @all_weekdays)

      {:ok, lv, html} = live(conn, ~p"/shift/tv")

      assert html =~ to_string(family.number)

      html =
        lv
        |> element("#tv-board button[phx-value-family_id=\"#{family.id}\"]")
        |> render_click()

      assert html =~ "Gerir empréstimos"
      assert html =~ "/shift/tv/#{family.id}?loaned-items"
    end

    test "the switch swaps the layout, not just the route", %{conn: conn} do
      {:ok, lv, html} = live(conn, ~p"/shift")
      assert html =~ "Lista de Espera"

      result =
        lv
        |> element("#display-mode-switch")
        |> render_hook("set-display-mode", %{"mode" => "tv"})

      {:ok, _tv_lv, tv_html} = follow_redirect(result, conn)

      # Live navigation, not a fresh mount - this is where a layout that only
      # applies on first mount would leave the sidebar stranded on the wall.
      refute tv_html =~ "Lista de Espera"
    end

    test "changing the day stays on the board", %{conn: conn, yesterday: yesterday} do
      {:ok, lv, _html} = live(conn, ~p"/shift/tv")

      go_to_yesterday(lv)

      assert assert_patch(lv) == "/shift/tv?date=#{Date.to_iso8601(yesterday)}"
    end
  end
end

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

  describe "a kit prepared before the swap" do
    defp swap_with(conn, family, target, kit_prepared) do
      {:ok, lv, _html} = live(conn, ~p"/shift")

      open_family(lv, family)
      click_action(lv, "Trocar dia")

      lv
      |> form("#add-swap-form",
        swap: %{to: Date.to_iso8601(target), kit_prepared: to_string(kit_prepared)}
      )
      |> render_submit()
    end

    test "is recorded when 'cabaz já feito' is ticked and tagged on the new day", %{conn: conn} do
      family = insert(:family, status: :active, weekdays: @all_weekdays)
      target = Date.add(Date.utc_today(), 3)

      assert swap_with(conn, family, target, true) =~ "Troca efetuada!"
      assert %Swap{kit_prepared: true} = Repo.get_by!(Swap, family_id: family.id)

      {:ok, lv, _html} = live(conn, ~p"/shift?date=#{Date.to_iso8601(target)}")

      assert lv
             |> element("#shift-list [data-family-id='#{family.id}']", "Cabaz pronto")
             |> has_element?()
    end

    test "is not tagged when 'cabaz já feito' is left unticked", %{conn: conn} do
      family = insert(:family, status: :active, weekdays: @all_weekdays)
      target = Date.add(Date.utc_today(), 3)

      swap_with(conn, family, target, false)
      assert %Swap{kit_prepared: false} = Repo.get_by!(Swap, family_id: family.id)

      {:ok, _lv, html} = live(conn, ~p"/shift?date=#{Date.to_iso8601(target)}")

      assert html =~ "Troca"
      refute html =~ "Cabaz pronto"
    end

    test "is only tagged on the day swapped to", %{conn: conn} do
      # Scheduled on both days, with a second swap *into* the from-day, so the
      # family is listed there too and the prepared swap is preloaded with it.
      from = Date.add(Date.utc_today(), 1)
      to = Date.add(Date.utc_today(), 2)

      family =
        insert(:family,
          status: :active,
          weekdays: [Family.weekday_from_date(from), Family.weekday_from_date(to)]
        )

      insert(:swap, family: family, from: from, to: to, kit_prepared: true)
      insert(:swap, family: family, from: Date.add(from, -7), to: from)

      {:ok, _lv, html} = live(conn, ~p"/shift?date=#{Date.to_iso8601(from)}")
      assert html =~ "F-#{family.number}"
      refute html =~ "Cabaz pronto"

      {:ok, _lv, html} = live(conn, ~p"/shift?date=#{Date.to_iso8601(to)}")
      assert html =~ "Cabaz pronto"
    end

    test "shows on the TV board too", %{conn: conn} do
      family = insert(:family, status: :active, weekdays: @all_weekdays)
      today = Date.utc_today()
      insert(:swap, family: family, from: Date.add(today, -1), to: today, kit_prepared: true)

      {:ok, lv, _html} = live(conn, ~p"/shift/tv")

      assert lv
             |> element("#tv-board [data-family-id='#{family.id}']", "Cabaz pronto")
             |> has_element?()
    end

    test "shares the TV row with restrictions and every other flag", %{conn: conn} do
      restrictions = "Sem glúten, sem lactose e alergia a frutos secos"

      family =
        insert(:family, status: :active, weekdays: @all_weekdays, restrictions: restrictions)

      today = Date.utc_today()
      insert(:swap, family: family, from: Date.add(today, -1), to: today, kit_prepared: true)
      insert(:absence, family: family, date: today, warned: false)
      insert(:loaned_item, family: family)

      {:ok, lv, _html} = live(conn, ~p"/shift/tv")

      row = "#tv-board [data-family-id='#{family.id}']"

      for text <- [restrictions, "Troca", "Cabaz pronto", "Faltou", "Empréstimo"] do
        assert lv |> element(row, text) |> has_element?(), "missing #{inspect(text)}"
      end
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

    test "renders a short date for phones and the long one from sm up", %{conn: conn} do
      date = ~D[2027-02-17]

      {:ok, lv, _html} = live(conn, ~p"/shift?date=#{Date.to_iso8601(date)}")

      assert lv
             |> element("#shift-list span.sm\\:hidden", Refood.Format.short_date(date))
             |> has_element?()

      assert lv
             |> element("#shift-list span.hidden.sm\\:inline", Refood.Format.long_date(date))
             |> has_element?()
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

  describe "family names" do
    test "shorten to first name, first middle name and last name", %{conn: conn} do
      for name <- [
            "Maria Ferreira Silva",
            "Joao Silva",
            "John Fraud Name Smith",
            "Ana da Costa Santos",
            "Rui dos Santos",
            "Cher"
          ] do
        insert(:family, name: name, status: :active, weekdays: @all_weekdays)
      end

      for path <- [~p"/shift", ~p"/shift/tv"] do
        {:ok, lv, _html} = live(conn, path)
        html = render(lv)

        assert html =~ ~r/>\s*Maria Ferreira Silva\s*</
        assert html =~ ~r/>\s*Joao Silva\s*</
        assert html =~ ~r/>\s*John Fraud Smith\s*</
        assert html =~ ~r/>\s*Ana Costa Santos\s*</
        assert html =~ ~r/>\s*Rui Santos\s*</
        assert html =~ ~r/>\s*Cher\s*</
      end
    end
  end
end

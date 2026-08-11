defmodule RefoodWeb.ShiftLiveTest do
  use RefoodWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Refood.AccountsFixtures
  import Refood.Factory

  alias Refood.Families.Swap
  alias Refood.Repo

  @all_weekdays [:monday, :tuesday, :wednesday, :thursday, :friday, :saturday, :sunday]

  setup %{conn: conn} do
    %{conn: log_in_user(conn, user_fixture()), yesterday: Date.add(Date.utc_today(), -1)}
  end

  defp go_to_yesterday(lv) do
    lv |> element("button[phx-click=prev-date]") |> render_click()
  end

  describe "adding a swap from a past shift date" do
    test "shows 'Trocar dia' when viewing a past date", %{conn: conn} do
      family = insert(:family, status: :active, weekdays: @all_weekdays)

      {:ok, lv, _html} = live(conn, ~p"/shift")

      go_to_yesterday(lv)

      html =
        lv
        |> element("#shift-table-mobile button[phx-value-family_id=\"#{family.id}\"]")
        |> render_click()

      assert html =~ "Trocar dia"
      assert html =~ "/shift/#{family.id}?new-swap"
    end

    test "creates a swap out of the past date", %{conn: conn, yesterday: yesterday} do
      family = insert(:family, status: :active, weekdays: @all_weekdays)
      target = Date.add(Date.utc_today(), 3)

      {:ok, lv, _html} = live(conn, ~p"/shift")
      go_to_yesterday(lv)

      render_patch(lv, ~p"/shift/#{family.id}?new-swap")

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

      render_patch(lv, ~p"/shift/#{family.id}?new-swap")

      html =
        lv
        |> form("#add-swap-form", swap: %{to: Date.to_iso8601(yesterday)})
        |> render_submit()

      assert html =~ "não é possível trocar para o passado"
      refute Repo.get_by(Swap, family_id: family.id)
    end
  end
end

defmodule RefoodWeb.FamiliesLive.FamilyDetailsTest do
  use RefoodWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Refood.AccountsFixtures
  import Refood.Factory

  alias Refood.Families.Swap
  alias Refood.Repo

  @all_weekdays [:monday, :tuesday, :wednesday, :thursday, :friday, :saturday, :sunday]

  defp open_family_details(conn, family) do
    live(conn, ~p"/families/#{family.id}?details")
  end

  defp admin_fixture do
    valid_user_attributes()
    |> Refood.Accounts.User.admin_registration_changeset()
    |> Repo.insert!()
  end

  describe "as a manager or admin" do
    for role <- [:manager, :admin] do
      test "sees 'Adicionar troca' and can create a swap (role: #{role})", %{conn: conn} do
        user =
          if unquote(role) == :admin, do: admin_fixture(), else: user_fixture(%{role: :manager})

        conn = log_in_user(conn, user)
        family = insert(:family, status: :active, weekdays: @all_weekdays)

        {:ok, lv, html} = open_family_details(conn, family)

        assert html =~ "+ Adicionar troca"

        lv |> element("a", "+ Adicionar troca") |> render_click()

        from = Date.utc_today()
        to = Date.add(from, 2)

        lv
        |> form("#swap-details-form",
          swap: %{from: Date.to_iso8601(from), to: Date.to_iso8601(to)}
        )
        |> render_submit()

        html = render(lv)

        assert html =~ "Sucesso!"
        assert html =~ "De #{from} para #{to}"
        assert %Swap{from: ^from, to: ^to} = Repo.get_by!(Swap, family_id: family.id)
      end
    end

    test "can edit an existing swap", %{conn: conn} do
      conn = log_in_user(conn, user_fixture(%{role: :manager}))
      family = insert(:family, status: :active, weekdays: @all_weekdays)
      from = Date.utc_today()
      swap = insert(:swap, family: family, from: from, to: Date.add(from, 1))
      new_to = Date.add(from, 5)

      {:ok, lv, _html} = open_family_details(conn, family)

      lv |> element("#swap-dropdown-#{swap.id}-dropdown a", "Editar troca") |> render_click()

      lv
      |> form("#swap-details-form",
        swap: %{from: Date.to_iso8601(from), to: Date.to_iso8601(new_to)}
      )
      |> render_submit()

      html = render(lv)

      assert html =~ "Sucesso!"
      assert html =~ "De #{from} para #{new_to}"
      assert %Swap{to: ^new_to} = Repo.get!(Swap, swap.id)
    end

    test "editing to a past date keeps the original swap and shows the error", %{conn: conn} do
      conn = log_in_user(conn, user_fixture(%{role: :manager}))
      family = insert(:family, status: :active, weekdays: @all_weekdays)
      from = Date.utc_today()
      original_to = Date.add(from, 1)
      swap = insert(:swap, family: family, from: from, to: original_to)
      yesterday = Date.add(from, -1)

      {:ok, lv, _html} = open_family_details(conn, family)

      lv |> element("#swap-dropdown-#{swap.id}-dropdown a", "Editar troca") |> render_click()

      html =
        lv
        |> form("#swap-details-form",
          swap: %{from: Date.to_iso8601(from), to: Date.to_iso8601(yesterday)}
        )
        |> render_submit()

      assert html =~ "não é possível trocar para o passado"
      assert %Swap{to: ^original_to} = Repo.get!(Swap, swap.id)
    end
  end

  describe "as a shift user" do
    test "does not see swap create/edit/delete controls", %{conn: conn} do
      conn = log_in_user(conn, user_fixture(%{role: :shift}))
      family = insert(:family, status: :active, weekdays: @all_weekdays)
      swap = insert(:swap, family: family)

      {:ok, _lv, html} = open_family_details(conn, family)

      refute html =~ "+ Adicionar troca"
      refute html =~ "swap-dropdown-#{swap.id}"
    end
  end
end

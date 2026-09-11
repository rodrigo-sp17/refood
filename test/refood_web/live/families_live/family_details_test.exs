defmodule RefoodWeb.FamiliesLive.FamilyDetailsTest do
  use RefoodWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Refood.AccountsFixtures
  import Refood.Factory

  alias Refood.Families.Swap
  alias Refood.Format
  alias Refood.Repo

  @all_weekdays [:monday, :tuesday, :wednesday, :thursday, :friday, :saturday, :sunday]

  defp open_family_details(conn, family) do
    live(conn, ~p"/families/#{family.id}?details")
  end

  # Loans, absences and swaps are records rather than form fields, so they live
  # on their own tab.
  defp open_history(lv) do
    lv |> element("button", "Histórico") |> render_click()
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

        {:ok, lv, _html} = open_family_details(conn, family)

        assert open_history(lv) =~ "Adicionar troca"

        lv |> element("button", "Adicionar troca") |> render_click()

        from = Date.utc_today()
        to = Date.add(from, 2)

        lv
        |> form("#swap-details-form",
          swap: %{from: Date.to_iso8601(from), to: Date.to_iso8601(to)}
        )
        |> render_submit()

        assert render(lv) =~ "Troca guardada!"

        html = open_history(lv)
        assert html =~ Format.date(from)
        assert html =~ Format.date(to)
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
      open_history(lv)

      lv |> element("#swap-dropdown-#{swap.id}-dropdown a", "Editar troca") |> render_click()

      lv
      |> form("#swap-details-form",
        swap: %{from: Date.to_iso8601(from), to: Date.to_iso8601(new_to)}
      )
      |> render_submit()

      assert render(lv) =~ "Troca guardada!"
      assert open_history(lv) =~ Format.date(new_to)
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
      open_history(lv)

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

      {:ok, lv, _html} = open_family_details(conn, family)

      html = open_history(lv)

      refute html =~ "Adicionar troca"
      refute html =~ "swap-dropdown-#{swap.id}"
    end
  end

  describe "read and edit modes" do
    test "reads as text and only offers editing to managers", %{conn: conn} do
      conn = log_in_user(conn, user_fixture(%{role: :manager}))
      family = insert(:family, status: :active, weekdays: [:wednesday], email: nil)

      {:ok, lv, html} = open_family_details(conn, family)

      # Read mode is text, not disabled inputs, and a blank field says so.
      refute html =~ ~s(name="family[name]")
      assert html =~ "—"
      assert html =~ "Editar"

      html = lv |> element("a", "Editar") |> render_click()

      # Editing swaps in the inputs and offers a save that is off until dirty.
      assert html =~ ~s(name="family[name]")
      assert html =~ "A editar"
      assert html =~ "Sem alterações"
      assert html =~ "disabled"

      html =
        lv
        |> form("#family-details-form", family: %{name: "Nome Novo"})
        |> render_change()

      assert html =~ "1 alteração por guardar"
    end

    test "a volunteer is never offered editing", %{conn: conn} do
      conn = log_in_user(conn, user_fixture(%{role: :shift}))
      family = insert(:family, status: :active, weekdays: [:wednesday])

      {:ok, _lv, html} = open_family_details(conn, family)

      refute html =~ "Editar"
    end
  end
end

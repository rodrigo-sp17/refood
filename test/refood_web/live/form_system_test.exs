defmodule RefoodWeb.FormSystemTest do
  @moduledoc """
  Cross-cutting checks on the shared form system.

  These exist because the bugs they cover were invisible: a section that
  rendered no inputs, and a validation error that never reached the screen.
  """
  use RefoodWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Refood.AccountsFixtures
  import Refood.Factory

  alias Refood.Repo

  setup %{conn: conn} do
    %{conn: log_in_user(conn, user_fixture(%{role: :manager}))}
  end

  describe "address fields on create forms" do
    test "a new family shows the Morada inputs", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/families?new-family")

      assert html =~ "Morada"
      assert html =~ ~s(name="family[address][region]")
      assert html =~ ~s(name="family[address][city]")
      # City is prefilled rather than hard-coded onto the input.
      assert html =~ ~s(value="Porto")
    end

    test "a new help request shows the Morada inputs", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/help-queue?new-request")

      assert html =~ "Morada"
      assert html =~ ~s(name="family[address][region]")
      assert html =~ ~s(name="family[address][zipcode]")
    end
  end

  describe "moving a family to regular help" do
    test "shows the error when the number is already taken", %{conn: conn} do
      insert(:family, status: :active, number: 42)
      queued = insert(:family, status: :queued, number: nil, weekdays: [])

      {:ok, lv, _html} = live(conn, ~p"/help-queue/#{queued.id}?move-to-active")

      html =
        lv
        |> form("#move-to-active-form", family: %{number: 42, weekdays: [:wednesday]})
        |> render_submit()

      # This used to be swallowed entirely - the modal simply did nothing.
      assert html =~ "número já assimilado"
      assert Repo.reload!(queued).status == :queued
    end

    test "keeps the form open and validates as you type", %{conn: conn} do
      insert(:family, status: :active, number: 42)
      queued = insert(:family, status: :queued, number: nil, weekdays: [])

      {:ok, lv, _html} = live(conn, ~p"/help-queue/#{queued.id}?move-to-active")

      html =
        lv
        |> form("#move-to-active-form", family: %{number: 42, weekdays: [:wednesday]})
        |> render_change()

      # The form used to have no phx-change at all.
      assert html =~ ~s(name="family[number]")
    end
  end

  describe "error messages" do
    test "Ecto's own messages come out in Portuguese", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/families?new-family")

      html =
        lv
        |> form("#new-family-form", family: %{name: ""})
        |> render_submit()

      assert html =~ "não pode ficar vazio"
      refute html =~ "can&#39;t be blank"
    end

    test "a failed submit says so instead of appearing to do nothing", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/families?new-family")

      html =
        lv
        |> form("#new-family-form", family: %{name: ""})
        |> render_submit()

      assert html =~ "Não foi possível guardar"
    end
  end

  describe "every form renders" do
    test "the fridge forms render with the shared primitives", %{conn: conn} do
      insert(:fridge)

      {:ok, _lv, html} = live(conn, ~p"/fridges?new-fridge")
      assert html =~ "new-fridge-form"

      {:ok, _lv, html} = live(conn, ~p"/fridges?new-record")
      assert html =~ "new-temperature-form"
      assert html =~ ~s(name="records[recorded_at]")
    end

    test "the user forms render", %{conn: conn} do
      admin =
        valid_user_attributes()
        |> Refood.Accounts.User.admin_registration_changeset()
        |> Repo.insert!()

      {:ok, lv, _html} = conn |> log_in_user(admin) |> live(~p"/user-management")

      html = lv |> element("button", "Criar novo usuário") |> render_click()
      assert html =~ "registration-form"
      assert html =~ ~s(name="user[email]")
    end
  end
end

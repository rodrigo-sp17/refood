defmodule RefoodWeb.ShiftTicketLiveTest do
  use RefoodWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Refood.Factory

  alias Refood.Shifts

  @all_weekdays [:monday, :tuesday, :wednesday, :thursday, :friday, :saturday, :sunday]

  defp family(attrs \\ []) do
    insert(:family, Keyword.merge([status: :active, weekdays: @all_weekdays], attrs))
  end

  defp open_shift! do
    {:ok, code} = Shifts.open_shift()
    code
  end

  defp enter_code(lv, code) do
    lv |> form("form[phx-submit=submit-code]", %{"code" => code}) |> render_submit()
  end

  defp enter_number(lv, number) do
    lv
    |> form("form[phx-submit=submit-number]", %{"number" => to_string(number)})
    |> render_submit()
  end

  defp confirm(lv) do
    lv |> element("button[phx-click=confirm-family]") |> render_click()
  end

  describe "the page is reachable without logging in" do
    test "no session or user is required", %{conn: conn} do
      open_shift!()

      assert {:ok, _lv, html} = live(conn, ~p"/tickets/claim")
      assert html =~ "Insira o código do dia"
    end
  end

  describe "when no shift is open" do
    test "shows the closed state and no family data", %{conn: conn} do
      fam = family()

      {:ok, _lv, html} = live(conn, ~p"/tickets/claim")

      assert html =~ "A fila ainda não está aberta"
      refute html =~ "F-#{fam.number}"
      refute html =~ fam.name
    end
  end

  describe "code entry" do
    setup do
      %{code: open_shift!(), family: family()}
    end

    test "a wrong code shows an error and does not advance", %{conn: conn, code: code} do
      {:ok, lv, _html} = live(conn, ~p"/tickets/claim")
      wrong = if code.code == "0000", do: "1111", else: "0000"

      html = enter_code(lv, wrong)

      assert html =~ "Código inválido"
      refute html =~ "Qual é o número da sua família?"
    end

    test "the input is disabled after 5 wrong attempts", %{conn: conn, code: code} do
      {:ok, lv, _html} = live(conn, ~p"/tickets/claim")
      wrong = if code.code == "0000", do: "1111", else: "0000"

      for _ <- 1..4, do: enter_code(lv, wrong)
      html = enter_code(lv, wrong)

      assert html =~ "Demasiadas tentativas"
      assert html =~ "disabled"
      refute html =~ "Continuar"

      # The server must refuse too, not just the disabled input: a scripted client
      # would ignore the DOM entirely. Pushing the event directly bypasses it.
      html = render_submit(lv, "submit-code", %{"code" => code.code})
      refute html =~ "Qual é o número da sua família?"
    end

    test "the correct code asks for the family number", %{conn: conn, code: code} do
      {:ok, lv, _html} = live(conn, ~p"/tickets/claim")

      html = enter_code(lv, code.code)

      assert html =~ "Qual é o número da sua família?"
    end
  end

  describe "number entry" do
    setup %{conn: conn} do
      code = open_shift!()
      fam = family()
      {:ok, lv, _html} = live(conn, ~p"/tickets/claim")
      enter_code(lv, code.code)

      %{lv: lv, code: code, family: fam}
    end

    test "no family numbers are offered - the family types its own", %{lv: lv, family: fam} do
      html = render(lv)

      refute html =~ "F-#{fam.number}"
      assert html =~ ~s(name="number")
      assert html =~ ~s(maxlength="3")
      assert html =~ ~s(inputmode="numeric")
    end

    test "a valid number asks for confirmation before claiming", %{lv: lv, family: fam} do
      html = enter_number(lv, fam.number)

      assert html =~ "É a família F-#{fam.number}?"
      assert Shifts.get_ticket(fam.id) == nil
    end

    test "confirming shows the position", %{lv: lv, family: fam} do
      enter_number(lv, fam.number)
      html = confirm(lv)

      assert html =~ "A sua senha"
      assert %{position: 1} = Shifts.get_ticket(fam.id)
    end

    test "correcting returns to the number field without claiming", %{lv: lv, family: fam} do
      enter_number(lv, fam.number)
      html = lv |> element("button[phx-click=back-to-number]") |> render_click()

      assert html =~ "Qual é o número da sua família?"
      assert Shifts.get_ticket(fam.id) == nil
    end

    test "re-entering the same number returns the same position", %{
      conn: conn,
      code: code,
      family: fam
    } do
      {:ok, ticket} = Shifts.claim_ticket(fam.id)

      {:ok, lv, _html} = live(conn, ~p"/tickets/claim")
      enter_code(lv, code.code)
      enter_number(lv, fam.number)
      html = confirm(lv)

      assert html =~ "A sua senha"
      assert %{id: id} = Shifts.get_ticket(fam.id)
      assert id == ticket.id
    end
  end

  describe "rejected numbers all look the same" do
    setup %{conn: conn} do
      code = open_shift!()
      {:ok, lv, _html} = live(conn, ~p"/tickets/claim")
      enter_code(lv, code.code)
      %{lv: lv}
    end

    test "an unknown number", %{lv: lv} do
      assert enter_number(lv, 998) =~ "Não encontrámos esse número para hoje"
    end

    test "a family not scheduled today", %{lv: lv} do
      other_weekday =
        @all_weekdays
        |> List.delete(Refood.Families.Family.weekday_from_date(Date.utc_today()))
        |> hd()

      unscheduled = family(weekdays: [other_weekday])

      html = enter_number(lv, unscheduled.number)

      assert html =~ "Não encontrámos esse número para hoje"
      refute html =~ "É a família"
    end

    test "a family already marked absent", %{lv: lv} do
      absent = family()
      insert(:absence, family: absent, date: Date.utc_today())

      html = enter_number(lv, absent.number)

      assert html =~ "Não encontrámos esse número para hoje"
      refute html =~ "É a família"
    end

    test "junk input", %{lv: lv} do
      for junk <- ["", "abc", "0", "-1"] do
        assert enter_number(lv, junk) =~ "Não encontrámos esse número para hoje"
      end
    end
  end

  describe "the code gate cannot be skipped" do
    setup do
      %{code: open_shift!(), family: family()}
    end

    # The page is public and the DOM is not a control: a client can push any event
    # at any time. These must be refused by the server, not just hidden.
    test "submit-number pushed before the code is entered claims nothing and leaks nothing",
         %{conn: conn, family: fam} do
      {:ok, lv, _html} = live(conn, ~p"/tickets/claim")

      html = render_submit(lv, "submit-number", %{"number" => to_string(fam.number)})

      refute html =~ "É a família F-#{fam.number}?"
      assert html =~ "Insira o código do dia"
    end

    test "confirm-family pushed before the code is entered claims nothing", %{
      conn: conn,
      family: fam
    } do
      {:ok, lv, _html} = live(conn, ~p"/tickets/claim")

      render_submit(lv, "submit-number", %{"number" => to_string(fam.number)})
      render_click(lv, "confirm-family", %{})

      assert Shifts.get_ticket(fam.id) == nil
      assert render(lv) =~ "Insira o código do dia"
    end

    test "confirm-family with nothing selected does not crash the page", %{
      conn: conn,
      code: code
    } do
      {:ok, lv, _html} = live(conn, ~p"/tickets/claim")
      enter_code(lv, code.code)

      render_click(lv, "confirm-family", %{})

      assert render(lv) =~ "Qual é o número da sua família?"
    end
  end

  describe "a ticket that stops being valid" do
    setup %{conn: conn} do
      code = open_shift!()
      fam = family()
      {:ok, lv, _html} = live(conn, ~p"/tickets/claim")
      enter_code(lv, code.code)
      enter_number(lv, fam.number)
      confirm(lv)

      %{lv: lv, family: fam}
    end

    test "a volunteer revoking the senha takes it off the family's screen", %{
      lv: lv,
      family: fam
    } do
      assert render(lv) =~ "Aguarde ser chamado"

      ticket = Shifts.get_ticket(fam.id)
      {:ok, _} = Shifts.delete_ticket(ticket.id)

      html = render(lv)

      refute html =~ "Aguarde ser chamado"
      assert html =~ "A sua senha foi anulada"
      assert html =~ "Qual é o número da sua família?"
    end

    test "reopening the shift sends the family back to the code, since numbering reset",
         %{lv: lv} do
      {:ok, _} = Shifts.close_shift()
      {:ok, _} = Shifts.open_shift()

      html = render(lv)

      refute html =~ "A sua senha"
      assert html =~ "Insira o código do dia"
    end

    test "expiry leaves the senha on screen - it is still the family's place in line",
         %{lv: lv, family: fam} do
      code = Shifts.get_open_shift()

      code
      |> Ecto.Changeset.change(
        expires_at: DateTime.utc_now() |> DateTime.add(-1, :hour) |> DateTime.truncate(:second)
      )
      |> Refood.Repo.update!()

      # Force the refresh that any other shift activity would trigger.
      send(lv.pid, {:shift_updated, :probe})

      assert render(lv) =~ "Aguarde ser chamado"
      assert Shifts.get_ticket(fam.id)
    end

    test "rotating the code does not disturb a family mid-flow", %{lv: lv} do
      {:ok, _} = Shifts.rotate_code()

      assert render(lv) =~ "A sua senha"
    end
  end

  describe "privacy" do
    test "no family name or number ever reaches the page", %{conn: conn} do
      code = open_shift!()
      fam = family(name: "Muito Secreto Apelido")
      other = family(name: "Outra Familia")

      {:ok, lv, entry} = live(conn, ~p"/tickets/claim")
      numbers = enter_code(lv, code.code)
      confirmed = enter_number(lv, fam.number)
      done = confirm(lv)

      for html <- [entry, numbers, confirmed, done] do
        refute html =~ "Muito Secreto"
        refute html =~ "Outra Familia"
        # Nobody else's number is ever exposed, only the one the family typed.
        refute html =~ "F-#{other.number}"
      end
    end

    test "restrictions are not rendered", %{conn: conn} do
      code = open_shift!()
      fam = family(restrictions: "sem gluten unico")

      {:ok, lv, _html} = live(conn, ~p"/tickets/claim")
      enter_code(lv, code.code)
      html = enter_number(lv, fam.number)

      refute html =~ "sem gluten unico"
    end
  end

  describe "shift closing mid-flow" do
    test "drops the page back to the closed state", %{conn: conn} do
      code = open_shift!()
      family()

      {:ok, lv, _html} = live(conn, ~p"/tickets/claim")
      enter_code(lv, code.code)

      {:ok, _} = Shifts.close_shift()

      assert render(lv) =~ "A fila ainda não está aberta"
    end
  end
end

defmodule RefoodWeb.ShiftLiveTest do
  use RefoodWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Refood.AccountsFixtures
  import Refood.Factory

  alias Refood.Families.Swap
  alias Refood.Shifts
  alias Refood.Repo

  @all_weekdays [:monday, :tuesday, :wednesday, :thursday, :friday, :saturday, :sunday]

  setup %{conn: conn} do
    %{conn: log_in_user(conn, user_fixture()), yesterday: Date.add(Date.utc_today(), -1)}
  end

  defp expire(code) do
    code
    |> Ecto.Changeset.change(
      expires_at: DateTime.utc_now() |> DateTime.add(-1, :hour) |> DateTime.truncate(:second)
    )
    |> Repo.update!()
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

  describe "shift code panel" do
    test "the chip shows the queue is closed, and opening it reveals the code", %{conn: conn} do
      {:ok, lv, html} = live(conn, ~p"/shift")

      assert html =~ "Fila fechada"
      refute html =~ "Escreva este código no quadro"

      html = lv |> element("#shift-code-chip") |> render_click()
      assert html =~ "A fila está fechada"

      html = lv |> element("button[phx-click=open-shift]") |> render_click()

      code = Shifts.get_open_shift()
      # Stays in the modal so the new code can be copied straight to the whiteboard.
      assert html =~ "Escreva este código no quadro"
      assert html =~ code.code
    end

    test "the chip carries the code once the queue is open", %{conn: conn} do
      {:ok, code} = Shifts.open_shift()

      {:ok, lv, html} = live(conn, ~p"/shift")

      assert html =~ "Cód. fila"
      assert html =~ code.code

      # The instructions and destructive actions live behind the chip, not in the page.
      refute html =~ "Gerar novo código"

      html = lv |> element("#shift-code-chip") |> render_click()
      assert html =~ "Gerar novo código"
      assert html =~ "Fechar fila"
    end

    test "hands the raw UTC expiry to the client to format locally", %{conn: conn} do
      {:ok, code} = Shifts.open_shift()

      {:ok, lv, html} = live(conn, ~p"/shift")

      # The browser formats this in its own timezone (LocalTime hook). The server
      # must not render a time itself - it has no timezone configured, so it would
      # be an hour off through Portuguese summer time.
      assert html =~ ~s(phx-hook="LocalTime")
      assert html =~ ~s(data-utc="#{DateTime.to_iso8601(code.expires_at)}")

      html = lv |> element("#shift-code-chip") |> render_click()
      assert html =~ ~s(id="shift-code-modal-expiry")
      assert html =~ ~s(data-utc="#{DateTime.to_iso8601(code.expires_at)}")
    end

    test "an expired code keeps the queue on screen and offers recovery", %{conn: conn} do
      family = insert(:family, status: :active, weekdays: @all_weekdays)
      {:ok, code} = Shifts.open_shift()
      {:ok, _} = Shifts.claim_ticket(family.id)
      expire(code)

      {:ok, lv, html} = live(conn, ~p"/shift")

      # The ordering must survive - families are still queued holding those numbers.
      assert html =~ "Na fila (1)"
      assert html =~ ~s(data-queue-position="1")
      assert html =~ "Código expirado"
      refute html =~ code.code

      html = lv |> element("#shift-code-chip") |> render_click()
      assert html =~ "O código expirou"
      assert html =~ "Abrir nova fila"
    end

    test "reopening after expiry is confirmed, then restarts numbering", %{conn: conn} do
      family = insert(:family, status: :active, weekdays: @all_weekdays)
      {:ok, code} = Shifts.open_shift()
      {:ok, _} = Shifts.claim_ticket(family.id)
      expire(code)

      {:ok, lv, _html} = live(conn, ~p"/shift")
      lv |> element("#shift-code-chip") |> render_click()
      lv |> element("button[phx-click=show-reopen-shift]") |> render_click()
      html = lv |> element("#reopen-shift button", "Abrir nova") |> render_click()

      assert Shifts.list_ticket_positions() == %{}
      assert html =~ Shifts.get_open_shift().code
    end

    test "a senha can still be revoked while the code is expired", %{conn: conn} do
      family = insert(:family, status: :active, weekdays: @all_weekdays)
      {:ok, code} = Shifts.open_shift()
      {:ok, _} = Shifts.claim_ticket(family.id)
      expire(code)

      {:ok, lv, _html} = live(conn, ~p"/shift")

      lv
      |> element("#shift-table-mobile button[phx-value-family_id='#{family.id}']")
      |> render_click()

      html = lv |> element("button[phx-click=remove-ticket]") |> render_click()

      assert html =~ "Senha removida!"
      assert Shifts.get_ticket(family.id) == nil
    end

    test "the chip is hidden on past and future dates", %{conn: conn} do
      Shifts.open_shift()

      {:ok, lv, html} = live(conn, ~p"/shift")
      assert html =~ "shift-code-chip"

      html = go_to_yesterday(lv)
      refute html =~ "shift-code-chip"
    end

    test "rotating keeps the queue but changes the code", %{conn: conn} do
      family = insert(:family, status: :active, weekdays: @all_weekdays)
      {:ok, old} = Shifts.open_shift()
      {:ok, _} = Shifts.claim_ticket(family.id)

      {:ok, lv, _html} = live(conn, ~p"/shift")
      lv |> element("#shift-code-chip") |> render_click()
      lv |> element("button[phx-click=show-rotate-code]") |> render_click()
      html = lv |> element("#rotate-code button", "Gerar novo") |> render_click()

      refute html =~ old.code
      assert html =~ Shifts.get_open_shift().code
      assert Shifts.list_ticket_positions() == %{family.id => 1}
    end

    test "closing discards the queue", %{conn: conn} do
      family = insert(:family, status: :active, weekdays: @all_weekdays)
      {:ok, _} = Shifts.open_shift()
      {:ok, _} = Shifts.claim_ticket(family.id)

      {:ok, lv, _html} = live(conn, ~p"/shift")
      lv |> element("#shift-code-chip") |> render_click()
      lv |> element("button[phx-click=show-close-shift]") |> render_click()
      html = lv |> element("#close-shift button", "Fechar fila") |> render_click()

      assert html =~ "Fila fechada"
      assert Shifts.list_ticket_positions() == %{}
      refute html =~ "Na fila"
    end
  end

  describe "queue ordering" do
    test "queued families come first, in arrival order", %{conn: conn} do
      [a, b, c] =
        for n <- 1..3, do: insert(:family, number: n, status: :active, weekdays: @all_weekdays)

      {:ok, _} = Shifts.open_shift()
      {:ok, _} = Shifts.claim_ticket(c.id)
      {:ok, _} = Shifts.claim_ticket(a.id)

      {:ok, _lv, html} = live(conn, ~p"/shift")

      assert html =~ "Na fila (2)"
      assert html =~ "Por chegar (1)"

      order =
        Regex.scan(~r/data-family-id="([^"]+)"/, html)
        |> Enum.map(fn [_, id] -> id end)
        |> Enum.uniq()

      # c claimed first, then a; b has not arrived and keeps number order at the end.
      assert order == [c.id, a.id, b.id]
    end

    test "shows the position badge for queued families only", %{conn: conn} do
      queued = insert(:family, status: :active, weekdays: @all_weekdays)
      waiting = insert(:family, status: :active, weekdays: @all_weekdays)
      {:ok, _} = Shifts.open_shift()
      {:ok, _} = Shifts.claim_ticket(queued.id)

      {:ok, _lv, html} = live(conn, ~p"/shift")

      assert html =~ ~s(data-queue-position="1")
      refute html =~ ~s(data-queue-position="2")
      assert html =~ "F-#{waiting.number}"
    end

    test "reserves the badge gutter on waiting cards too, so numbers stay aligned", %{conn: conn} do
      queued = insert(:family, status: :active, weekdays: @all_weekdays)
      insert(:family, status: :active, weekdays: @all_weekdays)
      {:ok, _} = Shifts.open_shift()
      {:ok, _} = Shifts.claim_ticket(queued.id)

      {:ok, _lv, html} = live(conn, ~p"/shift")

      # One badge, but a gutter on every card in each surface (mobile list + TV grid)
      # - otherwise queued rows step right and break the column.
      assert html |> String.split(~s(data-queue-position=)) |> length() == 3
      gutters = html |> String.split(~s(2xl:w-14 2xl:h-14)) |> length()
      assert gutters == 5
    end

    test "no sections or badges when nothing is queued", %{conn: conn} do
      insert(:family, status: :active, weekdays: @all_weekdays)
      {:ok, _} = Shifts.open_shift()

      {:ok, _lv, html} = live(conn, ~p"/shift")

      refute html =~ "Na fila"
      refute html =~ "Por chegar"
      refute html =~ "data-queue-position"
    end

    test "a future date never shows a queue", %{conn: conn} do
      family = insert(:family, status: :active, weekdays: @all_weekdays)
      {:ok, _} = Shifts.open_shift()
      {:ok, _} = Shifts.claim_ticket(family.id)

      {:ok, lv, html} = live(conn, ~p"/shift")
      assert html =~ "Na fila"

      html = lv |> element("button[phx-click=next-date]") |> render_click()

      refute html =~ "Na fila"
      refute html =~ "data-queue-position"
    end
  end

  describe "volunteer ticket actions" do
    setup %{conn: conn} do
      family = insert(:family, status: :active, weekdays: @all_weekdays)
      {:ok, _} = Shifts.open_shift()
      {:ok, lv, _html} = live(conn, ~p"/shift")

      %{lv: lv, family: family}
    end

    test "gives a ticket from the family actions modal", %{lv: lv, family: family} do
      lv
      |> element("#shift-table-mobile button[phx-value-family_id='#{family.id}']")
      |> render_click()

      html = lv |> element("button[phx-click=give-ticket]") |> render_click()

      assert html =~ "Senha 1 atribuída!"
      assert %{position: 1, source: :volunteer} = Shifts.get_ticket(family.id)
    end

    test "removes a ticket, freeing the family to claim again", %{lv: lv, family: family} do
      {:ok, _} = Shifts.claim_ticket(family.id)

      lv
      |> element("#shift-table-mobile button[phx-value-family_id='#{family.id}']")
      |> render_click()

      html = lv |> element("button[phx-click=remove-ticket]") |> render_click()

      assert html =~ "Senha removida!"
      assert Shifts.get_ticket(family.id) == nil
    end

    test "ticket actions are absent when the queue is closed", %{conn: conn, family: family} do
      {:ok, _} = Shifts.close_shift()

      {:ok, lv, _html} = live(conn, ~p"/shift")

      html =
        lv
        |> element("#shift-table-mobile button[phx-value-family_id='#{family.id}']")
        |> render_click()

      refute html =~ "give-ticket"
      refute html =~ "remove-ticket"
    end
  end

  describe "live updates" do
    test "a claim elsewhere reorders the list without a reload", %{conn: conn} do
      [a, b] =
        for n <- 1..2, do: insert(:family, number: n, status: :active, weekdays: @all_weekdays)

      {:ok, _} = Shifts.open_shift()
      {:ok, lv, html} = live(conn, ~p"/shift")
      refute html =~ "Na fila"

      {:ok, _} = Shifts.claim_ticket(b.id)

      html = render(lv)

      assert html =~ "Na fila (1)"
      assert html =~ ~s(data-queue-position="1")

      order =
        Regex.scan(~r/data-family-id="([^"]+)"/, html)
        |> Enum.map(fn [_, id] -> id end)
        |> Enum.uniq()

      assert order == [b.id, a.id]
    end
  end
end

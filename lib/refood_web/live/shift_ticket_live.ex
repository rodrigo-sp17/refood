defmodule RefoodWeb.ShiftTicketLive do
  @moduledoc """
  Public, unauthenticated page where a family claims its ticket ("senha") for the day.

  Reached by scanning a printed poster, so the URL carries no secret and never
  changes. The secret is the day's 4-digit code, which volunteers write on a
  whiteboard on site - typing it is what proves the family is actually there.

  The family then types its own number. Nothing about any family is ever rendered:
  this page is readable from the street, so it must neither list who is expected
  today nor let a stranger probe which numbers exist.

  Built mobile-first - it is almost always used on a phone.
  """
  use RefoodWeb, :live_view

  alias Refood.Shifts

  @max_attempts 5
  @max_family_number 999

  defp max_attempts, do: @max_attempts

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Refood.PubSub, "shift_updates")
    end

    assigns = [
      page_title: "Senha",
      date: Date.utc_today(),
      step: initial_step(),
      shift_code_id: nil,
      attempts: 0,
      selected_family: nil,
      ticket: nil,
      error: nil
    ]

    {:ok, assign(socket, assigns), layout: {RefoodWeb.Layouts, :public}}
  end

  defp initial_step do
    if Shifts.get_open_shift(), do: :code_entry, else: :closed
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div :if={@step == :closed} class="mt-16 flex flex-col items-center gap-4 text-center">
      <.icon name="hero-clock" class="w-12 h-12 bg-gray-400" />
      <h1 class="text-2xl font-bold">A fila ainda não está aberta.</h1>
      <p class="text-gray-600">Aguarde a abertura pelos voluntários.</p>
    </div>

    <div :if={@step == :code_entry} class="mt-12 flex flex-col items-center gap-6">
      <h1 class="text-2xl font-bold text-center">Insira o código do dia</h1>
      <p class="text-gray-600 text-center">O código está no quadro.</p>

      <form phx-submit="submit-code" class="w-full flex flex-col items-center gap-4">
        <input
          type="text"
          name="code"
          inputmode="numeric"
          pattern="[0-9]*"
          maxlength="4"
          autocomplete="off"
          autofocus
          disabled={@attempts >= max_attempts()}
          class="w-48 text-center text-5xl font-mono tracking-[0.3em] py-4 rounded-lg border-2 border-gray-300 focus:border-gray-800 disabled:bg-gray-100 disabled:text-gray-400"
        />
        <p :if={@error} class="text-red-600 text-center">{@error}</p>
        <.button :if={@attempts < max_attempts()} class="w-full py-4 text-lg">Continuar</.button>
      </form>
    </div>

    <div :if={@step == :number_entry} class="mt-12 flex flex-col items-center gap-6">
      <h1 class="text-2xl font-bold text-center">Qual é o número da sua família?</h1>

      <form phx-submit="submit-number" class="w-full flex flex-col items-center gap-6">
        <div class="flex items-center gap-2">
          <span class="text-5xl font-bold text-gray-700">F-</span>
          <input
            type="text"
            name="number"
            inputmode="numeric"
            pattern="[0-9]*"
            maxlength="3"
            autocomplete="off"
            autofocus
            class="w-36 text-center text-5xl font-mono py-4 rounded-lg border-2 border-gray-300 focus:border-gray-800"
          />
        </div>
        <p :if={@error} class="text-red-600 text-center">{@error}</p>
        <.button class="w-full py-4 text-lg">Continuar</.button>
      </form>
    </div>

    <div :if={@step == :confirm} class="mt-16 flex flex-col items-center gap-8">
      <h1 class="text-2xl font-bold text-center">
        É a família F-{@selected_family.number}?
      </h1>
      <div class="w-full flex flex-col gap-3">
        <.button phx-click="confirm-family" class="w-full py-4 text-lg">Sim, é a minha</.button>
        <button
          phx-click="back-to-number"
          class="w-full py-4 text-lg rounded-lg border border-gray-300"
        >
          Não, corrigir
        </button>
      </div>
    </div>

    <div :if={@step == :done} class="mt-16 flex flex-col items-center gap-6 text-center">
      <p class="text-xl text-gray-600">A sua senha</p>
      <div class="text-8xl font-bold">{@ticket.position}</div>
      <p class="text-xl">Família F-{@selected_family.number}</p>
      <p class="text-gray-600">Aguarde ser chamado por este número.</p>
    </div>
    """
  end

  @impl true
  def handle_event("submit-code", %{"code" => code}, socket) do
    cond do
      socket.assigns.attempts >= @max_attempts ->
        {:noreply, socket}

      Shifts.valid_code?(code, socket.assigns.date) ->
        # Remember which shift this code belonged to, so a later reopen (a new row,
        # new numbering) can be told apart from a mere code rotation (same row).
        shift = Shifts.get_open_shift(socket.assigns.date)
        {:noreply, assign(socket, step: :number_entry, shift_code_id: shift.id, error: nil)}

      true ->
        attempts = socket.assigns.attempts + 1

        error =
          if attempts >= @max_attempts do
            "Demasiadas tentativas. Peça ajuda a um voluntário."
          else
            "Código inválido. O código está no quadro."
          end

        {:noreply, assign(socket, attempts: attempts, error: error)}
    end
  end

  # Every step below the code gate matches on the step it belongs to. The rendered
  # DOM is not a control: this page is public, so a client can push any event at any
  # time. Without these guards a passer-by could skip code entry entirely - claiming
  # tickets, and using the confirmation prompt as an oracle for which family numbers
  # exist and who is expected today.
  @impl true
  def handle_event(
        "submit-number",
        %{"number" => number},
        %{assigns: %{step: :number_entry}} = socket
      ) do
    with {:ok, number} <- parse_number(number),
         %{} = family <- Shifts.get_claimable_family(number, socket.assigns.date) do
      {:noreply, assign(socket, selected_family: family, step: :confirm, error: nil)}
    else
      _ -> {:noreply, assign(socket, error: unknown_number_message())}
    end
  end

  @impl true
  def handle_event("back-to-number", _, %{assigns: %{step: :confirm}} = socket) do
    {:noreply, assign(socket, selected_family: nil, step: :number_entry, error: nil)}
  end

  @impl true
  def handle_event(
        "confirm-family",
        _,
        %{assigns: %{step: :confirm, selected_family: %{} = family}} = socket
      ) do
    case Shifts.claim_ticket(family.id, socket.assigns.date, :family) do
      {:ok, ticket} ->
        {:noreply, assign(socket, ticket: ticket, step: :done)}

      {:error, reason} when reason in [:shift_closed, :shift_expired] ->
        {:noreply, assign(socket, step: :closed, selected_family: nil)}

      {:error, _reason} ->
        assigns = [selected_family: nil, step: :number_entry, error: unknown_number_message()]
        {:noreply, assign(socket, assigns)}
    end
  end

  # Any of the above pushed from the wrong step is ignored rather than trusted.
  @impl true
  def handle_event(event, _params, socket)
      when event in ~w(submit-number back-to-number confirm-family) do
    {:noreply, socket}
  end

  @impl true
  def handle_info({:shift_updated, _event}, socket) do
    %{step: step, date: date, shift_code_id: shift_code_id} = socket.assigns
    # The shift, not the code's validity: a family holding a senha keeps seeing it
    # after the code expires. Only closing or reopening takes it away.
    shift = Shifts.get_shift(date)

    cond do
      step in [:closed, :code_entry] ->
        {:noreply, assign(socket, step: initial_step())}

      # Shift closed underneath us.
      shift == nil ->
        {:noreply, reset(socket, :closed)}

      # Reopened: a different shift row, so numbering restarted and the code the
      # family typed is stale. Rotating the code keeps the same row and is therefore
      # deliberately not disruptive to anyone mid-flow.
      shift.id != shift_code_id ->
        {:noreply, reset(socket, :code_entry)}

      # A volunteer can revoke a ticket ("Remover senha"). Never keep showing a
      # number that is no longer theirs - someone else may hold it by now.
      step == :done and Shifts.get_ticket(socket.assigns.selected_family.id, date) == nil ->
        socket = reset(socket, :number_entry)
        {:noreply, assign(socket, error: "A sua senha foi anulada. Peça ajuda a um voluntário.")}

      true ->
        {:noreply, socket}
    end
  end

  defp reset(socket, step) do
    assign(socket, step: step, selected_family: nil, ticket: nil, error: nil)
  end

  defp parse_number(raw) do
    case Integer.parse(String.trim(raw)) do
      {number, ""} when number > 0 and number <= @max_family_number -> {:ok, number}
      _ -> :error
    end
  end

  # One message for every failure - unknown number, not scheduled today, already
  # marked absent. Distinguishing them would let anyone holding the code enumerate
  # which family numbers exist and who is expected today.
  defp unknown_number_message do
    "Não encontrámos esse número para hoje. Peça ajuda a um voluntário."
  end
end

defmodule RefoodWeb.ShiftLive do
  @moduledoc """
  Handles daily shift summary and shift displays.
  """
  use RefoodWeb, :live_view

  alias Refood.Families
  alias Refood.Shifts
  alias RefoodWeb.HelpQueueLive.NewHelpRequest
  alias RefoodWeb.ShiftLive.LoanedItems

  @tv_columns 2
  # Rows fit on screen is reported by the "TvGridSize" JS hook once connected; this is
  # only the pre-connect/no-JS floor, matching the minimum the hook itself enforces.
  @tv_min_rows 10
  @tv_rotate_interval_ms 10_000

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Refood.PubSub, "shift_updates")
      schedule_next_tv_page()
    end

    date = Date.utc_today()

    assigns =
      [date: date, tv_rows: @tv_min_rows, tv_trim: 0, selected_family: nil, view_to_show: nil] ++
        shift_assigns(date, @tv_min_rows)

    {:ok, assign(socket, assigns)}
  end

  @impl true
  def handle_params(%{"new-request" => _}, _uri, socket) do
    {:noreply, assign(socket, view_to_show: :new_request)}
  end

  @impl true
  def handle_params(%{"new-absence" => _, "family_id" => family_id}, _uri, socket) do
    assigns = [selected_family: family_id, view_to_show: :new_absence]
    {:noreply, assign(socket, assigns)}
  end

  @impl true
  def handle_params(%{"new-swap" => _, "family_id" => family_id}, _, socket) do
    assigns = [
      selected_family: family_id,
      view_to_show: :new_swap,
      form: to_form(Families.swap_changeset())
    ]

    {:noreply, assign(socket, assigns)}
  end

  @impl true
  def handle_params(%{"loaned-items" => _, "family_id" => family_id}, _, socket) do
    assigns = [
      selected_family: family_id,
      view_to_show: :loaned_items
    ]

    {:noreply, assign(socket, assigns)}
  end

  @impl true
  def handle_params(_, _uri, socket) do
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.header>
      Turno
      <%!-- Shown on the TV too, so it scales up at 2xl to stay readable from across
      the room. Note this puts the code in front of anyone who can see the display. --%>
      <:middle>
        <button
          :if={@date == Date.utc_today()}
          id="shift-code-chip"
          phx-click="show-shift-code"
          class="flex items-center gap-3 px-4 py-2 2xl:px-6 2xl:py-3 rounded-lg border border-zinc-300 hover:bg-zinc-50"
        >
          <span :if={@open_shift} class="text-xs 2xl:text-sm uppercase tracking-wide text-zinc-500">
            Cód. fila
          </span>
          <span :if={@open_shift} class="text-2xl 2xl:text-4xl font-mono font-bold tracking-[0.15em]">
            {@open_shift.code}
          </span>
          <span :if={@open_shift} class="text-xs 2xl:text-sm text-zinc-500">
            até <.local_time id="shift-code-chip-expiry" at={@open_shift.expires_at} />
          </span>
          <span
            :if={!@open_shift && @shift}
            class="flex items-center gap-2 text-sm 2xl:text-lg text-rose-600"
          >
            <.icon name="hero-exclamation-triangle" class="w-4 h-4 bg-rose-600" /> Código expirado
          </span>
          <span
            :if={!@open_shift && !@shift}
            class="flex items-center gap-2 text-sm 2xl:text-lg text-zinc-500"
          >
            <.icon name="hero-lock-closed" class="w-4 h-4 bg-zinc-400" /> Fila fechada
          </span>
        </button>
      </:middle>
      <:actions>
        <.link patch="/shift?new-request">
          <.button>
            Criar pedido de ajuda
          </.button>
        </.link>
      </:actions>
    </.header>

    <.live_component
      :if={@view_to_show == :new_request}
      module={NewHelpRequest}
      id="new-help-request"
      on_cancel={JS.push("cancel-modal")}
    />

    <.confirmation_modal
      :if={@view_to_show == :new_absence}
      id="add-absence"
      question="A família avisou com antecedência sobre a falta?"
      type={:delete}
      confirm_text="Não avisou"
      on_confirm={JS.push("add-absence", value: %{"warned" => false})}
      deny_text="Avisou"
      on_deny={JS.push("add-absence", value: %{"warned" => true})}
      on_cancel={JS.push("cancel-modal")}
    />

    <.modal
      :if={@view_to_show == :shift_code}
      id="shift-code-modal"
      show
      on_cancel={JS.push("cancel-modal")}
    >
      <div :if={@open_shift} class="flex flex-col items-center gap-6">
        <h2 class="text-2xl text-center">Código da fila</h2>
        <div id="shift-code" class="text-6xl font-mono font-bold tracking-[0.15em]">
          {@open_shift.code}
        </div>
        <p class="text-sm text-zinc-500">
          Válido até às <.local_time id="shift-code-modal-expiry" at={@open_shift.expires_at} />
        </p>
        <ol class="w-full flex flex-col gap-2 text-zinc-600 list-decimal list-inside">
          <li>Escreva este código no quadro.</li>
          <li>As famílias leem o cartaz e inserem o código no telemóvel.</li>
          <li>Cada família recebe a sua senha e aparece aqui por ordem de chegada.</li>
        </ol>
        <div class="w-full flex flex-col gap-3">
          <.secondary_button phx-click="show-rotate-code">Gerar novo código</.secondary_button>
          <.secondary_button variant={:danger} phx-click="show-close-shift">
            Fechar fila
          </.secondary_button>
        </div>
      </div>
      <div :if={!@open_shift && @shift} class="flex flex-col items-center gap-6">
        <h2 class="text-2xl text-center">O código expirou</h2>
        <p class="text-center text-zinc-600">
          As senhas já dadas continuam visíveis e por ordem, mas nenhuma família
          consegue tirar senha até abrir uma nova fila.
        </p>
        <div class="w-full flex flex-col gap-3">
          <.secondary_button variant={:danger} phx-click="show-reopen-shift">
            Abrir nova fila
          </.secondary_button>
          <.secondary_button variant={:danger} phx-click="show-close-shift">
            Fechar fila
          </.secondary_button>
        </div>
      </div>
      <div :if={!@open_shift && !@shift} class="flex flex-col items-center gap-6">
        <h2 class="text-2xl text-center">A fila está fechada</h2>
        <p class="text-center text-zinc-600">
          Abra a fila para gerar um código do dia. Escreva-o no quadro para as famílias
          poderem tirar senha.
        </p>
        <.button phx-click="open-shift" class="w-full">Abrir fila</.button>
      </div>
    </.modal>

    <.confirmation_modal
      :if={@view_to_show == :reopen_shift}
      id="reopen-shift"
      question="Abrir uma nova fila? As senhas de hoje são apagadas e a numeração recomeça do 1."
      type={:delete}
      confirm_text="Abrir nova"
      on_confirm={JS.push("open-shift")}
      deny_text="Cancelar"
      on_deny={JS.push("show-shift-code")}
      on_cancel={JS.push("show-shift-code")}
    />

    <.confirmation_modal
      :if={@view_to_show == :rotate_code}
      id="rotate-code"
      question="Gerar um novo código? O código atual deixa de funcionar, mas as senhas já dadas são mantidas."
      confirm_text="Gerar novo"
      on_confirm={JS.push("rotate-code")}
      deny_text="Cancelar"
      on_deny={JS.push("show-shift-code")}
      on_cancel={JS.push("show-shift-code")}
    />

    <.confirmation_modal
      :if={@view_to_show == :close_shift}
      id="close-shift"
      question="Fechar a fila? Todas as senhas do dia são apagadas e a numeração recomeça do 1."
      type={:delete}
      confirm_text="Fechar fila"
      on_confirm={JS.push("close-shift")}
      deny_text="Cancelar"
      on_deny={JS.push("show-shift-code")}
      on_cancel={JS.push("show-shift-code")}
    />

    <.modal :if={@view_to_show == :new_swap} id="add-swap" show on_cancel={JS.push("cancel-modal")}>
      <div class="flex flex-col gap-10">
        <h2 class="text-2xl text-center">Para qual dia deseja trocar?</h2>
        <.simple_form id="add-swap-form" for={@form} phx-submit="add-swap">
          <.input type="date" field={@form[:to]} min={Date.utc_today()} />
          <:actions>
            <.button class="w-full">Trocar</.button>
          </:actions>
        </.simple_form>
      </div>
    </.modal>

    <.live_component
      :if={@view_to_show == :loaned_items}
      module={LoanedItems}
      id="loaned-items"
      family_id={@selected_family}
      on_cancel={JS.push("cancel-modal")}
    />

    <.modal
      :if={@view_to_show == :family_actions}
      id="family-actions"
      show
      on_cancel={JS.push("cancel-modal")}
    >
      <% family = Enum.find(@families, &(&1.id == @selected_family)) %>
      <div :if={family} class="flex flex-col gap-6">
        <h2 class="text-xl font-bold text-center">
          <span :if={@positions[family.id]}>Senha {@positions[family.id]} –</span>
          F-{family.number} – {family.name}
        </h2>
        <div class="flex flex-col gap-3">
          <.secondary_button
            :if={@open_shift && !@positions[family.id]}
            phx-click="give-ticket"
            phx-value-family_id={family.id}
          >
            Dar senha
          </.secondary_button>
          <.secondary_button
            :if={@positions[family.id]}
            phx-click="remove-ticket"
            phx-value-family_id={family.id}
          >
            Remover senha
          </.secondary_button>
          <.secondary_button
            :if={show_add_swap?(family, @date)}
            patch={"/shift/#{family.id}?new-swap"}
          >
            Trocar dia
          </.secondary_button>
          <.secondary_button :if={show_add_absence?(family)} patch={"/shift/#{family.id}?new-absence"}>
            Marcar falta
          </.secondary_button>
          <.secondary_button patch={"/shift/#{family.id}?loaned-items"}>
            Gerir empréstimos
          </.secondary_button>
        </div>
      </div>
    </.modal>

    <div class="mt-11 flex justify-center items-center gap-8 mb-8">
      <button
        phx-click="prev-date"
        class="flex items-center rounded-full bg-white group hover:bg-black border border-black p-1"
      >
        <.icon name="hero-chevron-left" class="bg-black group-hover:bg-white" />
      </button>
      <div class="flex flex-col items-center gap-4">
        <div class="basis-7/12 text-3xl text-center font-bold">
          {if @date == Date.utc_today(), do: "(Hoje)"} {"#{weekday_name(Date.day_of_week(@date))}, #{@date.day} de #{month_name(@date.month)} de #{@date.year}"}
        </div>
        <div class="text-xl">Total: {length(@families)}</div>
      </div>
      <button
        phx-click="next-date"
        class="flex items-center rounded-full bg-white group hover:bg-black border border-black p-1"
      >
        <.icon name="hero-chevron-right" class="bg-black group-hover:bg-white" />
      </button>
    </div>
    <div id="shift-table-mobile" class="2xl:hidden overflow-y-auto flex flex-col items-center gap-2">
      <div :if={@families == []} class="h-16 flex justify-center items-center">
        Nenhuma família para o dia.
      </div>
      <%= if @queued_families == [] do %>
        <.family_card :for={family <- @families} family={family} date={@date} />
      <% else %>
        <div id="shift-queued" class="w-full flex flex-col gap-2">
          <h3 class="text-sm font-bold uppercase tracking-wide text-gray-500">
            Na fila ({length(@queued_families)})
          </h3>
          <.family_card
            :for={family <- @queued_families}
            family={family}
            date={@date}
            position={@positions[family.id]}
            reserve_position
          />
        </div>
        <div :if={@waiting_families != []} id="shift-waiting" class="w-full flex flex-col gap-2">
          <h3 class="text-sm font-bold uppercase tracking-wide text-gray-500 mt-4">
            Por chegar ({length(@waiting_families)})
          </h3>
          <.family_card
            :for={family <- @waiting_families}
            family={family}
            date={@date}
            reserve_position
          />
        </div>
      <% end %>
    </div>
    <div id="shift-table-tv" class="hidden 2xl:flex 2xl:flex-col 2xl:h-full 2xl:min-h-0 2xl:gap-2">
      <div :if={@families == []} class="h-16 flex justify-center items-center">
        Nenhuma família para o dia.
      </div>
      <div
        id="shift-table-tv-grid"
        phx-hook="TvGridSize"
        class="2xl:grid 2xl:grid-cols-2 2xl:gap-3 2xl:flex-1 2xl:min-h-0 2xl:pb-4"
        style={"grid-template-rows: repeat(#{@tv_rows}, minmax(min-content, 1fr));"}
      >
        <.family_card
          :for={family <- tv_page_families(@families, @page, @tv_rows, @tv_trim)}
          family={family}
          date={@date}
          position={@positions[family.id]}
          reserve_position={@queued_families != []}
        />
      </div>
      <div :if={@total_pages > 1} class="flex justify-center gap-2 pb-2">
        <div
          :for={i <- 0..(@total_pages - 1)}
          class={[
            "w-2.5 h-2.5 rounded-full",
            if(i == @page, do: "bg-black", else: "bg-gray-300")
          ]}
        />
      </div>
    </div>
    """
  end

  attr :family, :map, required: true
  attr :date, Date, required: true
  attr :position, :integer, default: nil
  attr :reserve_position, :boolean, default: false

  defp family_card(assigns) do
    ~H"""
    <div
      class={
        [
          "relative w-full px-4 py-3 bg-white flex flex-col md:flex-row md:flex-wrap rounded-lg justify-start md:items-start gap-2 2xl:h-full 2xl:items-center 2xl:flex-nowrap",
          # An inset ring rather than a background tint: it survives being read from
          # across the room on the TV, and adds no hue that would collide with the
          # Troca / Avisou / Faltou / Emprestimo badges inside the card.
          @position && "ring-2 ring-inset ring-zinc-900"
        ]
      }
      data-family-id={@family.id}
    >
      <button
        class="absolute inset-0 rounded-lg"
        phx-click="show-family-actions"
        phx-value-family_id={@family.id}
      />
      <div class="flex items-center gap-2 md:gap-0 shrink">
        <%!-- Reserved on every card while anyone is queued, so the family numbers
        stay in one column instead of stepping right for queued rows. --%>
        <div
          :if={@reserve_position}
          class="shrink-0 flex items-center justify-center mr-2 w-9 h-9 2xl:w-14 2xl:h-14"
        >
          <div
            :if={@position}
            class="w-full h-full rounded-full bg-zinc-900 text-white flex items-center justify-center text-lg 2xl:text-3xl font-bold"
            data-queue-position={@position}
          >
            {@position}
          </div>
        </div>
        <div class="text-xl font-bold w-11">F-{@family.number}</div>
        <div class="text-lg md:pl-2 break-words w-44" title={@family.name}>
          {short_name(@family.name)}
        </div>
      </div>
      <div class="text-lg md:pl-2 flex items-center gap-3 flex-shrink-0">
        <.icon name="hero-users-solid" />{@family.adults} + {@family.children}
      </div>
      <div class="md:px-2 flex-1 flex flex-col md:flex-row gap-2 flex-1 min-w-0 2xl:items-center">
        <div class="flex items-center min-w-5">
          <%= if @family.restrictions do %>
            <div class="flex items-center gap-1">
              <.icon name="hero-exclamation-triangle-solid text-red-700 shrink-0" />
              <p class="text-red-700 break-words 2xl:max-w-40">
                {@family.restrictions}
              </p>
            </div>
          <% else %>
            -
          <% end %>
        </div>
        <div class="flex items-center flex-wrap 2xl:flex-nowrap flex-1 grow gap-2">
          <div
            :if={!Enum.empty?(@family.swaps)}
            class="px-3 py-0.5 border rounded-3xl border-green-600 text-green-600 text-center text-sm font-bold whitespace-nowrap shrink-0"
          >
            Troca
          </div>
          <div :for={absence <- @family.absences}>
            <div
              :if={absence.warned}
              class="px-3 py-0.5 border rounded-3xl border-yellow-600 text-yellow-600 text-center text-sm font-bold whitespace-nowrap shrink-0"
            >
              Avisou
            </div>
            <div
              :if={!absence.warned}
              class="px-3 py-0.5 border rounded-3xl border-red-500 text-red-500 text-center text-sm font-bold whitespace-nowrap shrink-0"
            >
              Faltou
            </div>
          </div>
          <div
            :if={!Enum.empty?(@family.unreturned_loaned_items)}
            class="px-3 py-0.5 border rounded-3xl border-blue-600 text-blue-600 text-center text-sm font-bold whitespace-nowrap shrink-0"
          >
            Empréstimo
          </div>
        </div>
      </div>
    </div>
    """
  end

  # The pagination window itself (offset and page count) is always based on the
  # untrimmed page size, so trimming never shifts which families a given page
  # starts from - only trim (below) shortens how many of them get rendered. If the
  # window moved with the trim, trimming would shift the next family into view,
  # which could resolve the overflow that caused the trim, undoing it, re-causing
  # the overflow, etc. - an endless flicker between two states.
  defp tv_base_page_size(tv_rows), do: tv_rows * @tv_columns

  defp tv_page_families(families, page, tv_rows, tv_trim) do
    base_size = tv_base_page_size(tv_rows)
    page_size = max(@tv_columns, base_size - tv_trim)
    Enum.slice(families, page * base_size, page_size)
  end

  defp tv_total_pages(families, tv_rows),
    do: max(1, ceil(length(families) / tv_base_page_size(tv_rows)))

  # Families that have claimed a ticket come first, in the order they arrived; the
  # rest keep the query's family-number order. With no open shift `positions` is
  # empty, so past and future dates collapse to exactly the previous behaviour.
  defp shift_assigns(date, tv_rows, page \\ 0) do
    positions = Shifts.list_ticket_positions(date)
    {queued, waiting} = Enum.split_with(Families.list_families_by_date(date), &positions[&1.id])
    queued = Enum.sort_by(queued, &positions[&1.id])
    families = queued ++ waiting
    total_pages = tv_total_pages(families, tv_rows)

    [
      families: families,
      queued_families: queued,
      waiting_families: waiting,
      positions: positions,
      open_shift: Shifts.get_open_shift(date),
      shift: Shifts.get_shift(date),
      page: page |> min(total_pages - 1) |> max(0),
      total_pages: total_pages
    ]
  end

  defp schedule_next_tv_page,
    do: Process.send_after(self(), :next_tv_page, @tv_rotate_interval_ms)

  defp short_name(name) do
    case String.split(name, " ", trim: true) do
      [single] -> single
      parts -> "#{List.first(parts)} #{List.last(parts)}"
    end
  end

  attr :id, :string, required: true
  attr :at, DateTime, required: true

  # The browser formats this, in its own timezone - see the LocalTime hook. Renders
  # empty until the hook runs, rather than showing a UTC time that would be wrong by
  # an hour half the year.
  defp local_time(assigns) do
    ~H"""
    <span id={@id} phx-hook="LocalTime" data-utc={DateTime.to_iso8601(@at)} />
    """
  end

  defp ticket_error_message(:shift_closed), do: "A fila não está aberta."
  defp ticket_error_message(:not_scheduled), do: "Família não escalada para o dia."
  defp ticket_error_message(:absent), do: "Família marcada como falta."
  defp ticket_error_message(_), do: "Falha ao atribuir senha."

  defp show_add_absence?(family) do
    family.absences == []
  end

  defp show_add_swap?(family, _date) do
    family.absences == [] && Enum.empty?(family.swaps)
  end

  @impl true
  def handle_event("prev-date", _, socket) do
    prev_date = Timex.shift(socket.assigns.date, days: -1)

    assigns = [date: prev_date] ++ shift_assigns(prev_date, socket.assigns.tv_rows)

    {:noreply, assign(socket, assigns)}
  end

  @impl true
  def handle_event("next-date", _, socket) do
    next_date = Timex.shift(socket.assigns.date, days: 1)

    assigns = [date: next_date] ++ shift_assigns(next_date, socket.assigns.tv_rows)

    {:noreply, assign(socket, assigns)}
  end

  @impl true
  def handle_event("add-absence", %{"warned" => warned?}, socket) do
    %{selected_family: family_id, date: date} = socket.assigns

    base_assigns = [
      selected_family: nil,
      view_to_show: nil
    ]

    case Families.add_absence(%{family_id: family_id, warned: warned?, date: date}) do
      {:ok, _} ->
        assigns =
          base_assigns ++
            shift_assigns(date, socket.assigns.tv_rows)

        {:noreply, socket |> assign(assigns) |> put_flash(:info, "Falta registrada!")}

      {:error, changeset} ->
        {:noreply, put_flash(socket, :error, "Falha em registrar falta: #{changeset.errors}")}
    end
  end

  @impl true
  def handle_event("add-swap", %{"swap" => attrs}, socket) do
    %{selected_family: family_id, date: date} = socket.assigns

    final_attrs = Map.merge(attrs, %{"family_id" => family_id, "from" => date})

    case Families.add_swap(final_attrs) do
      {:ok, _swap} ->
        assigns =
          [view_to_show: nil, selected_family: nil] ++
            shift_assigns(date, socket.assigns.tv_rows)

        {:noreply, socket |> assign(assigns) |> put_flash(:info, "Troca efetuada!")}

      {:error, changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  @impl true
  def handle_event("show-shift-code", _, socket) do
    {:noreply, assign(socket, view_to_show: :shift_code)}
  end

  @impl true
  def handle_event("show-reopen-shift", _, socket) do
    {:noreply, assign(socket, view_to_show: :reopen_shift)}
  end

  @impl true
  def handle_event("open-shift", _, socket) do
    %{date: date, tv_rows: tv_rows, page: page} = socket.assigns

    case Shifts.open_shift(date) do
      {:ok, _code} ->
        # Stay in the modal: it now shows the new code, which is what the volunteer
        # opened the queue to get.
        assigns = [view_to_show: :shift_code] ++ shift_assigns(date, tv_rows, page)

        {:noreply, socket |> assign(assigns) |> put_flash(:info, "Fila aberta!")}

      # Someone else opened it first - show them the code that is already live rather
      # than reporting a failure.
      {:error, :already_open} ->
        assigns = [view_to_show: :shift_code] ++ shift_assigns(date, tv_rows, page)
        {:noreply, socket |> assign(assigns) |> put_flash(:info, "A fila já estava aberta.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Falha ao abrir a fila.")}
    end
  end

  @impl true
  def handle_event("show-rotate-code", _, socket) do
    {:noreply, assign(socket, view_to_show: :rotate_code)}
  end

  @impl true
  def handle_event("rotate-code", _, socket) do
    %{date: date, tv_rows: tv_rows, page: page} = socket.assigns

    case Shifts.rotate_code(date) do
      {:ok, _code} ->
        assigns = [view_to_show: :shift_code] ++ shift_assigns(date, tv_rows, page)

        {:noreply,
         socket |> assign(assigns) |> put_flash(:info, "Novo código gerado. Atualize o quadro!")}

      {:error, _} ->
        {:noreply,
         socket |> assign(view_to_show: nil) |> put_flash(:error, "A fila não está aberta.")}
    end
  end

  @impl true
  def handle_event("show-close-shift", _, socket) do
    {:noreply, assign(socket, view_to_show: :close_shift)}
  end

  @impl true
  def handle_event("close-shift", _, socket) do
    %{date: date, tv_rows: tv_rows, page: page} = socket.assigns
    {:ok, _} = Shifts.close_shift(date)

    assigns = [view_to_show: nil] ++ shift_assigns(date, tv_rows, page)

    {:noreply, socket |> assign(assigns) |> put_flash(:info, "Fila fechada!")}
  end

  @impl true
  def handle_event("give-ticket", %{"family_id" => family_id}, socket) do
    %{date: date, tv_rows: tv_rows, page: page} = socket.assigns

    case Shifts.claim_ticket(family_id, date, :volunteer) do
      {:ok, ticket} ->
        assigns =
          [selected_family: nil, view_to_show: nil] ++ shift_assigns(date, tv_rows, page)

        {:noreply,
         socket |> assign(assigns) |> put_flash(:info, "Senha #{ticket.position} atribuída!")}

      {:error, reason} ->
        {:noreply,
         socket
         |> assign(selected_family: nil, view_to_show: nil)
         |> put_flash(:error, ticket_error_message(reason))}
    end
  end

  @impl true
  def handle_event("remove-ticket", %{"family_id" => family_id}, socket) do
    %{date: date, tv_rows: tv_rows, page: page} = socket.assigns

    case Shifts.get_ticket(family_id, date) do
      nil ->
        {:noreply, assign(socket, selected_family: nil, view_to_show: nil)}

      ticket ->
        {:ok, _} = Shifts.delete_ticket(ticket.id)
        assigns = [selected_family: nil, view_to_show: nil] ++ shift_assigns(date, tv_rows, page)

        {:noreply, socket |> assign(assigns) |> put_flash(:info, "Senha removida!")}
    end
  end

  @impl true
  def handle_event("show-family-actions", %{"family_id" => family_id}, socket) do
    {:noreply, assign(socket, selected_family: family_id, view_to_show: :family_actions)}
  end

  @impl true
  def handle_event("cancel-modal", _, socket) do
    socket = assign(socket, selected_family: nil, view_to_show: nil)
    {:noreply, push_patch(socket, to: "/shift")}
  end

  @impl true
  def handle_event("tv-rows-changed", %{"rows" => rows, "trim" => trim}, socket) do
    tv_rows = rows |> trunc() |> max(@tv_min_rows)
    tv_trim = trim |> trunc() |> max(0)
    %{families: families, page: page} = socket.assigns

    total_pages = tv_total_pages(families, tv_rows)

    assigns = [
      tv_rows: tv_rows,
      tv_trim: tv_trim,
      total_pages: total_pages,
      page: min(page, total_pages - 1)
    ]

    {:noreply, assign(socket, assigns)}
  end

  @impl true
  def handle_info({:help_request_created, _}, socket) do
    assigns = [selected_family: nil, view_to_show: nil]
    {:noreply, assign(socket, assigns)}
  end

  @impl true
  def handle_info({:loaned_item_added, _family_id}, socket) do
    %{date: date, tv_rows: tv_rows} = socket.assigns

    assigns =
      shift_assigns(date, tv_rows) ++
        [selected_family: nil, view_to_show: nil]

    {:noreply,
     socket
     |> assign(assigns)
     |> push_patch(to: "/shift")}
  end

  @impl true
  def handle_info({:loaned_item_updated, family_id}, socket) do
    %{date: date, tv_rows: tv_rows} = socket.assigns

    assigns =
      shift_assigns(date, tv_rows) ++
        [selected_family: family_id]

    {:noreply, socket |> assign(assigns)}
  end

  @impl true
  def handle_info({:shift_updated, _event}, socket) do
    %{date: date, tv_rows: tv_rows, page: page} = socket.assigns

    # Keep the page the TV is currently showing. Tickets are claimed continuously
    # during a shift, and resetting to the first page on every claim would drag the
    # display back mid-rotation.
    assigns = shift_assigns(date, tv_rows, page)

    {:noreply, assign(socket, assigns)}
  end

  @impl true
  def handle_info(:next_tv_page, socket) do
    schedule_next_tv_page()

    if socket.assigns.total_pages > 1 do
      next_page = rem(socket.assigns.page + 1, socket.assigns.total_pages)
      {:noreply, assign(socket, page: next_page)}
    else
      {:noreply, socket}
    end
  end

  defp weekday_name(1), do: "Segunda-feira"
  defp weekday_name(2), do: "Terça-feira"
  defp weekday_name(3), do: "Quarta-feira"
  defp weekday_name(4), do: "Quinta-feira"
  defp weekday_name(5), do: "Sexta-feira"
  defp weekday_name(6), do: "Sábado"
  defp weekday_name(7), do: "Domingo"

  defp month_name(1), do: "Janeiro"
  defp month_name(2), do: "Fevereiro"
  defp month_name(3), do: "Março"
  defp month_name(4), do: "Abril"
  defp month_name(5), do: "Maio"
  defp month_name(6), do: "Junho"
  defp month_name(7), do: "Julho"
  defp month_name(8), do: "Agosto"
  defp month_name(9), do: "Setembro"
  defp month_name(10), do: "Outubro"
  defp month_name(11), do: "Novembro"
  defp month_name(12), do: "Dezembro"
end

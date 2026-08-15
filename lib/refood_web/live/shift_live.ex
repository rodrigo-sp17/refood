defmodule RefoodWeb.ShiftLive do
  @moduledoc """
  Handles daily shift summary and shift displays.

  Two modes, chosen explicitly rather than by screen width:

    * `:index` - the ordinary page, on a tablet or phone in someone's hand.
      Full app shell, scrolling list, every action available.

    * `:tv` - the wall board, on its own route with a bare layout. Input-sparse
      but not input-free: it is driven by a remote, and exactly three
      interactions survive - the display switch, changing the day, and opening a
      family.

  Which one a device gets is remembered client-side (see the `ShiftDisplayMode`
  hook). Width is deliberately not a signal: a 27" desktop monitor is wider than
  the old breakpoint and is not a wall display.
  """
  use RefoodWeb, :live_view

  alias Refood.Families
  alias RefoodWeb.ShiftLive.LoanedItems

  # Rows and columns that fit on screen are reported by the "TvGridSize" hook
  # once connected; these are only the pre-connect/no-JS floor, matching the
  # minimum the hook itself enforces.
  @tv_min_rows 10
  @tv_min_columns 2
  @tv_rotate_interval_ms 10_000
  @tv_tick_interval_ms 60_000

  @impl true
  def mount(_params, _session, socket) do
    tv? = socket.assigns.live_action == :tv

    if connected?(socket) do
      Phoenix.PubSub.subscribe(Refood.PubSub, "shift_updates")

      if tv? do
        schedule_next_tv_page()
        schedule_next_tick()
      end
    end

    socket =
      assign(socket,
        date: nil,
        today: Date.utc_today(),
        families: [],
        page: 0,
        total_pages: 1,
        tv_rows: @tv_min_rows,
        tv_columns: @tv_min_columns,
        tv_trim: 0,
        tv_paused: false,
        selected_family: nil,
        view_to_show: nil
      )

    {:ok, socket, layout: layout_for(socket.assigns.live_action)}
  end

  defp layout_for(:tv), do: {RefoodWeb.Layouts, :bare}
  defp layout_for(_), do: {RefoodWeb.Layouts, :app}

  @impl true
  def handle_params(params, _uri, socket) do
    date = parse_date(params["date"]) || Date.utc_today()

    socket =
      socket
      |> load_families(date)
      |> assign(view_assigns(params))

    {:noreply, socket}
  end

  defp parse_date(nil), do: nil

  defp parse_date(raw) do
    case Date.from_iso8601(raw) do
      {:ok, date} -> date
      {:error, _} -> nil
    end
  end

  # Opening a modal patches the URL, so this runs far more often than the day
  # actually changes - only re-query when it did.
  defp load_families(%{assigns: %{date: date}} = socket, date), do: socket

  defp load_families(socket, date) do
    families = Families.list_families_by_date(date)
    assign(socket, [date: date] ++ families_page_assigns(families, socket.assigns))
  end

  defp view_assigns(%{"new-absence" => _, "family_id" => family_id}),
    do: [view_to_show: :new_absence, selected_family: family_id]

  defp view_assigns(%{"new-swap" => _, "family_id" => family_id}),
    do: [
      view_to_show: :new_swap,
      selected_family: family_id,
      form: to_form(Families.swap_changeset())
    ]

  defp view_assigns(%{"loaned-items" => _, "family_id" => family_id}),
    do: [view_to_show: :loaned_items, selected_family: family_id]

  defp view_assigns(_), do: []

  ## Rendering

  @impl true
  def render(%{live_action: :tv} = assigns) do
    ~H"""
    <.shift_modals {assigns} />

    <div class="h-full min-h-0 flex flex-col px-8 py-6">
      <header id="tv-header" class="shrink-0 flex items-center gap-5 pb-4">
        <.date_step direction={:prev} tv />
        <div class="flex items-baseline gap-3">
          <span class="text-[28px] font-bold uppercase tracking-wide text-zinc-900">
            {short_date(@date)}
          </span>
          <span
            :if={@date == @today}
            class="rounded-3xl bg-brand px-3 py-0.5 text-base font-bold text-zinc-900"
          >
            Hoje
          </span>
        </div>
        <.date_step direction={:next} tv />

        <div class="flex-1" />

        <div class="text-[24px] text-zinc-600">{summary(@families)}</div>
        <.switch
          id="display-mode-switch"
          phx-hook="ShiftDisplayMode"
          data-mode="tv"
          checked={true}
          label="Modo TV"
          class="tv-focus"
        />
      </header>

      <div class="h-0.5 shrink-0 bg-brand" />

      <div
        :if={@families == []}
        class="flex-1 flex items-center justify-center text-3xl text-zinc-500"
      >
        Nenhuma família hoje.
      </div>

      <div :if={@families != []} id="tv-board" phx-hook="TvGridNav" class="flex-1 min-h-0 flex">
        <div
          id="tv-board-grid"
          phx-hook="TvGridSize"
          class="flex-1 min-h-0 grid gap-3"
          style={"grid-template-columns: repeat(auto-fill, minmax(500px, 1fr)); grid-template-rows: repeat(#{@tv_rows}, minmax(min-content, 1fr));"}
        >
          <.board_row
            :for={family <- tv_page_families(@families, @page, @tv_rows, @tv_columns, @tv_trim)}
            family={family}
          />
        </div>
      </div>

      <div :if={@total_pages > 1} class="shrink-0 flex justify-center gap-2 pt-3">
        <div
          :for={i <- 0..(@total_pages - 1)}
          class={["w-2.5 h-2.5 rounded-full", if(i == @page, do: "bg-brand", else: "bg-zinc-300")]}
        />
      </div>
    </div>
    """
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.header>
      Turno
      <:actions>
        <.switch
          id="display-mode-switch"
          phx-hook="ShiftDisplayMode"
          data-mode="normal"
          checked={false}
          label="Modo TV"
        />
      </:actions>
    </.header>

    <.shift_modals {assigns} />

    <div id="shift-list" class="mt-6 flex-1 min-h-0 overflow-y-auto flex flex-col gap-2">
      <div class="sticky top-0 z-10 bg-zinc-100 pb-3 flex flex-col items-center gap-2">
        <div class="flex justify-center items-center gap-8">
          <.date_step direction={:prev} />
          <div class="w-[48ch] max-w-[80vw] text-3xl text-center font-bold">
            {if @date == @today, do: "(Hoje)"} {long_date(@date)}
          </div>
          <.date_step direction={:next} />
        </div>
        <div class="text-xl text-zinc-600">{summary(@families)}</div>
      </div>

      <div :if={@families == []} class="h-16 flex justify-center items-center">
        Nenhuma família para o dia.
      </div>
      <.family_card :for={family <- @families} family={family} />
    </div>
    """
  end

  ## Shared pieces

  attr :direction, :atom, required: true
  attr :tv, :boolean, default: false

  defp date_step(assigns) do
    ~H"""
    <button
      phx-click={if @direction == :prev, do: "prev-date", else: "next-date"}
      aria-label={if @direction == :prev, do: "Dia anterior", else: "Dia seguinte"}
      class={[
        "flex items-center rounded-full bg-white hover:bg-brand border border-brand",
        "focus-visible:outline-none",
        if(@tv,
          do: "p-2 tv-focus",
          else: "p-1 focus-visible:ring-2 focus-visible:ring-zinc-900 focus-visible:ring-offset-2"
        )
      ]}
    >
      <.icon
        name={if @direction == :prev, do: "hero-chevron-left", else: "hero-chevron-right"}
        class={if @tv, do: "bg-zinc-900 w-8 h-8", else: "bg-zinc-900"}
      />
    </button>
    """
  end

  # One board row. No card: on a wall, 40 rounded rectangles spend their pixels
  # on padding and corners, while a board spends them on the numbers.
  attr :family, :map, required: true

  defp board_row(assigns) do
    ~H"""
    <button
      data-family-id={@family.id}
      phx-click="show-family-actions"
      phx-value-family_id={@family.id}
      class={[
        "w-full h-full text-left flex items-start gap-5 px-5 py-2 rounded-lg border-b border-zinc-300",
        "focus:outline-none tv-focus-inset focus-visible:bg-white"
      ]}
    >
      <%!--
      Dimming is applied per block rather than to the whole row: who is not
      coming fades, but the word explaining why never does.
      --%>
      <div class={[
        "w-[4.5ch] shrink-0 text-right text-[44px] leading-none font-bold tabular-nums text-zinc-900",
        absent?(@family) && "opacity-45"
      ]}>
        <span class="text-[24px] font-medium text-zinc-400">F-</span>{@family.number}
      </div>

      <div class="flex-1 min-w-0 flex flex-col gap-1">
        <div class={["flex items-start gap-4", absent?(@family) && "opacity-45"]}>
          <%!--
          First and last name only, but wrapped rather than truncated: shortening
          is a decision about which words matter, an ellipsis is just the layout
          giving up mid-word.
          --%>
          <span
            class="flex-1 min-w-0 break-words text-[26px] leading-tight font-medium text-zinc-900"
            title={@family.name}
          >
            {short_name(@family.name)}
          </span>
          <%!--
          Household size decides how big the bag is, so it reads as data, not as
          a caption. Each part gets a fixed cell so the digits and the "+" land
          on the same x in every row - a column you can scan, not three numbers
          that drift with their own width.
          --%>
          <span class="shrink-0 flex items-center gap-1.5 text-[28px] leading-tight font-semibold tabular-nums text-zinc-900">
            <.icon name="hero-users-solid" class="w-6 h-6 shrink-0 bg-zinc-400" />
            <span class="w-[2ch] text-right">{@family.adults}</span>
            <span class="text-zinc-400">+</span>
            <span class="w-[2ch] text-left">{@family.children}</span>
          </span>
        </div>

        <div :if={@family.restrictions || flagged?(@family)} class="flex items-start gap-4">
          <div class={[
            "flex-1 min-w-0 flex items-start gap-1.5 text-[22px] leading-tight text-rose-700",
            absent?(@family) && "opacity-45"
          ]}>
            <.icon
              :if={@family.restrictions}
              name="hero-exclamation-triangle-solid"
              class="shrink-0 w-7 h-7 bg-rose-700"
            />
            <span class="min-w-0 break-words">{@family.restrictions}</span>
          </div>

          <div class="shrink-0 flex flex-wrap justify-end gap-x-3 text-[20px] leading-tight font-bold uppercase tracking-wide">
            <span :if={!Enum.empty?(@family.swaps)} class="text-emerald-600">Troca</span>
            <span
              :for={absence <- @family.absences}
              class={if absence.warned, do: "text-amber-600", else: "text-rose-600"}
            >
              {if absence.warned, do: "Avisou", else: "Faltou"}
            </span>
            <span :if={!Enum.empty?(@family.unreturned_loaned_items)} class="text-blue-600">
              Empréstimo
            </span>
          </div>
        </div>
      </div>
    </button>
    """
  end

  attr :family, :map, required: true

  defp family_card(assigns) do
    ~H"""
    <div
      class="relative w-full px-4 py-3 bg-white flex flex-col md:flex-row md:flex-wrap rounded-lg justify-start md:items-start gap-2"
      data-family-id={@family.id}
    >
      <button
        class="absolute inset-0 rounded-lg transition-colors hover:bg-zinc-900/5 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-zinc-900 focus-visible:ring-offset-2"
        phx-click="show-family-actions"
        phx-value-family_id={@family.id}
      />
      <div class="flex items-center gap-2 md:gap-0 shrink">
        <div class="text-xl font-bold w-11">F-{@family.number}</div>
        <div class="text-lg md:pl-2 break-words w-44" title={@family.name}>
          {short_name(@family.name)}
        </div>
      </div>
      <div class="text-lg md:pl-2 flex items-center gap-3 flex-shrink-0">
        <.icon name="hero-users-solid" />{@family.adults} + {@family.children}
      </div>
      <div class="md:px-2 flex-1 flex flex-col md:flex-row gap-2 flex-1 min-w-0">
        <div class="flex items-center min-w-5">
          <%= if @family.restrictions do %>
            <div class="flex items-center gap-1">
              <.icon name="hero-exclamation-triangle-solid text-rose-600 shrink-0" />
              <p class="text-rose-600 break-words">
                {@family.restrictions}
              </p>
            </div>
          <% else %>
            -
          <% end %>
        </div>
        <div class="flex items-center flex-wrap flex-1 grow gap-2">
          <.badge :if={!Enum.empty?(@family.swaps)} color={:success}>
            Troca
          </.badge>
          <div :for={absence <- @family.absences}>
            <.badge :if={absence.warned} color={:warning}>
              Avisou
            </.badge>
            <.badge :if={!absence.warned} color={:danger}>
              Faltou
            </.badge>
          </div>
          <.badge :if={!Enum.empty?(@family.unreturned_loaned_items)} color={:info}>
            Empréstimo
          </.badge>
        </div>
      </div>
    </div>
    """
  end

  # Shared verbatim between both modes - only the action links scale up, so a
  # remote-driven screen gets targets it can hit and text it can read.
  defp shift_modals(assigns) do
    ~H"""
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
        <h2 class={[
          "font-bold text-center",
          if(@live_action == :tv, do: "text-3xl", else: "text-xl")
        ]}>
          F-{family.number} – {family.name}
        </h2>
        <div class="flex flex-col gap-3">
          <.link
            :if={show_add_swap?(family)}
            patch={shift_path(@live_action, @date, family_id: family.id, flag: "new-swap")}
            class={action_link_class(@live_action)}
          >
            Trocar dia
          </.link>
          <.link
            :if={show_add_absence?(family)}
            patch={shift_path(@live_action, @date, family_id: family.id, flag: "new-absence")}
            class={action_link_class(@live_action)}
          >
            Marcar falta
          </.link>
          <.link
            patch={shift_path(@live_action, @date, family_id: family.id, flag: "loaned-items")}
            class={action_link_class(@live_action)}
          >
            Gerir empréstimos
          </.link>
        </div>
      </div>
    </.modal>
    """
  end

  defp action_link_class(:tv),
    do:
      "w-full px-6 py-5 text-center text-[28px] border border-zinc-300 rounded-lg hover:bg-zinc-50 " <>
        "focus-visible:outline-none tv-focus"

  defp action_link_class(_),
    do:
      "w-full px-4 py-3 text-center border border-zinc-300 rounded-lg hover:bg-zinc-50 " <>
        "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-zinc-900 focus-visible:ring-offset-2"

  ## Paths

  defp base_path(:tv), do: "/shift/tv"
  defp base_path(_), do: "/shift"

  # Every link back into the page carries both the mode - which decides the
  # route family actions patch to - and the date, which would otherwise reset to
  # today on the next handle_params. Built in one place so neither gets dropped.
  defp shift_path(live_action, date, opts \\ []) do
    segment = if id = opts[:family_id], do: "/#{id}", else: ""

    # Flag first: it keeps today's action URLs identical to the plain
    # "?new-swap" form rather than burying them behind the date.
    query = Enum.reject([opts[:flag], date_param(date)], &is_nil/1)

    base_path(live_action) <> segment <> query_string(query)
  end

  defp date_param(date) do
    if date == Date.utc_today(), do: nil, else: "date=#{Date.to_iso8601(date)}"
  end

  defp query_string([]), do: ""
  defp query_string(query), do: "?" <> Enum.join(query, "&")

  ## Board fitting

  # The pagination window itself (offset and page count) is always based on the
  # untrimmed page size, so trimming never shifts which families a given page
  # starts from - only trim (below) shortens how many of them get rendered. If the
  # window moved with the trim, trimming would shift the next family into view,
  # which could resolve the overflow that caused the trim, undoing it, re-causing
  # the overflow, etc. - an endless flicker between two states.
  defp tv_base_page_size(tv_rows, tv_columns), do: tv_rows * tv_columns

  defp tv_page_families(families, page, tv_rows, tv_columns, tv_trim) do
    base_size = tv_base_page_size(tv_rows, tv_columns)
    page_size = max(tv_columns, base_size - tv_trim)
    Enum.slice(families, page * base_size, page_size)
  end

  defp tv_total_pages(families, tv_rows, tv_columns),
    do: max(1, ceil(length(families) / tv_base_page_size(tv_rows, tv_columns)))

  defp families_page_assigns(families, %{tv_rows: tv_rows, tv_columns: tv_columns}) do
    [families: families, page: 0, total_pages: tv_total_pages(families, tv_rows, tv_columns)]
  end

  defp schedule_next_tv_page,
    do: Process.send_after(self(), :next_tv_page, @tv_rotate_interval_ms)

  defp schedule_next_tick,
    do: Process.send_after(self(), :tick, @tv_tick_interval_ms)

  ## Presentation helpers

  defp short_name(name) do
    case String.split(name, " ", trim: true) do
      [single] -> single
      parts -> "#{List.first(parts)} #{List.last(parts)}"
    end
  end

  defp absent?(family), do: family.absences != []

  defp flagged?(family) do
    family.absences != [] || !Enum.empty?(family.swaps) ||
      !Enum.empty?(family.unreturned_loaned_items)
  end

  defp summary(families) do
    absences = Enum.count(families, &absent?/1)
    swaps = Enum.count(families, &(not Enum.empty?(&1.swaps)))

    [
      pluralize(length(families), "família", "famílias"),
      absences > 0 && pluralize(absences, "falta", "faltas"),
      swaps > 0 && pluralize(swaps, "troca", "trocas")
    ]
    |> Enum.filter(& &1)
    |> Enum.join(" · ")
  end

  defp pluralize(1, singular, _plural), do: "1 #{singular}"
  defp pluralize(count, _singular, plural), do: "#{count} #{plural}"

  defp show_add_absence?(family), do: family.absences == []
  defp show_add_swap?(family), do: family.absences == [] && Enum.empty?(family.swaps)

  ## Events

  @impl true
  def handle_event("prev-date", _, socket), do: {:noreply, step_date(socket, -1)}

  @impl true
  def handle_event("next-date", _, socket), do: {:noreply, step_date(socket, 1)}

  @impl true
  def handle_event("set-display-mode", %{"mode" => mode}, socket) do
    action = if mode == "tv", do: :tv, else: :index
    {:noreply, push_navigate(socket, to: shift_path(action, socket.assigns.date))}
  end

  @impl true
  def handle_event("add-absence", %{"warned" => warned?}, socket) do
    %{selected_family: family_id, date: date} = socket.assigns

    case Families.add_absence(%{family_id: family_id, warned: warned?, date: date}) do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign([selected_family: nil, view_to_show: nil] ++ reload(socket, date))
         |> put_flash(:info, "Falta registrada!")}

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
        {:noreply,
         socket
         |> assign([view_to_show: nil, selected_family: nil] ++ reload(socket, date))
         |> put_flash(:info, "Troca efetuada!")}

      {:error, changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  @impl true
  def handle_event("show-family-actions", %{"family_id" => family_id}, socket) do
    {:noreply, assign(socket, selected_family: family_id, view_to_show: :family_actions)}
  end

  @impl true
  def handle_event("cancel-modal", _, socket) do
    %{live_action: live_action, date: date} = socket.assigns

    {:noreply,
     socket
     |> assign(selected_family: nil, view_to_show: nil)
     |> push_patch(to: shift_path(live_action, date))}
  end

  @impl true
  def handle_event(
        "tv-rows-changed",
        %{"rows" => rows, "trim" => trim, "columns" => columns},
        socket
      ) do
    tv_rows = rows |> trunc() |> max(@tv_min_rows)
    tv_columns = columns |> trunc() |> max(1)
    tv_trim = trim |> trunc() |> max(0)

    total_pages = tv_total_pages(socket.assigns.families, tv_rows, tv_columns)

    assigns = [
      tv_rows: tv_rows,
      tv_columns: tv_columns,
      tv_trim: tv_trim,
      total_pages: total_pages,
      page: min(socket.assigns.page, total_pages - 1)
    ]

    {:noreply, assign(socket, assigns)}
  end

  @impl true
  def handle_event("tv-focus", %{"focused" => focused?}, socket) do
    {:noreply, assign(socket, tv_paused: focused?)}
  end

  defp step_date(socket, days) do
    date = Date.add(socket.assigns.date, days)
    push_patch(socket, to: shift_path(socket.assigns.live_action, date))
  end

  ## Messages

  @impl true
  def handle_info({:loaned_item_added, _family_id}, socket) do
    %{live_action: live_action, date: date} = socket.assigns

    {:noreply,
     socket
     |> assign([selected_family: nil, view_to_show: nil] ++ reload(socket, date))
     |> push_patch(to: shift_path(live_action, date))}
  end

  @impl true
  def handle_info({:loaned_item_updated, family_id}, socket) do
    {:noreply,
     assign(socket, [selected_family: family_id] ++ reload(socket, socket.assigns.date))}
  end

  @impl true
  def handle_info({:shift_updated, _event}, socket) do
    {:noreply, assign(socket, reload(socket, socket.assigns.date))}
  end

  @impl true
  def handle_info(:next_tv_page, socket) do
    schedule_next_tv_page()

    %{page: page, total_pages: total_pages} = socket.assigns

    # Never rotate out from under someone: a board that moves while a modal is
    # open, or while the remote is walking the grid, is disorienting.
    if total_pages > 1 && !socket.assigns.tv_paused && is_nil(socket.assigns.view_to_show) do
      {:noreply, assign(socket, page: rem(page + 1, total_pages))}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info(:tick, socket) do
    schedule_next_tick()

    today = Date.utc_today()

    cond do
      today == socket.assigns.today ->
        {:noreply, socket}

      # A board left running since Wednesday should not still say Wednesday -
      # but only follow the clock if it is still showing what "today" meant when
      # it was loaded. Someone who paged to tomorrow with the remote keeps it.
      socket.assigns.date == socket.assigns.today ->
        {:noreply, assign(socket, [today: today] ++ reload(socket, today, force: true))}

      true ->
        {:noreply, assign(socket, today: today)}
    end
  end

  defp reload(socket, date, opts \\ []) do
    assigns = families_page_assigns(Families.list_families_by_date(date), socket.assigns)
    if opts[:force], do: [date: date] ++ assigns, else: assigns
  end

  ## Dates

  defp long_date(date) do
    "#{weekday_name(Date.day_of_week(date))}, #{date.day} de #{month_name(date.month)} de #{date.year}"
  end

  defp short_date(date) do
    "#{weekday_short(Date.day_of_week(date))}, #{date.day} #{month_short(date.month)}"
  end

  defp weekday_name(1), do: "Segunda-feira"
  defp weekday_name(2), do: "Terça-feira"
  defp weekday_name(3), do: "Quarta-feira"
  defp weekday_name(4), do: "Quinta-feira"
  defp weekday_name(5), do: "Sexta-feira"
  defp weekday_name(6), do: "Sábado"
  defp weekday_name(7), do: "Domingo"

  defp weekday_short(1), do: "Seg"
  defp weekday_short(2), do: "Ter"
  defp weekday_short(3), do: "Qua"
  defp weekday_short(4), do: "Qui"
  defp weekday_short(5), do: "Sex"
  defp weekday_short(6), do: "Sáb"
  defp weekday_short(7), do: "Dom"

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

  defp month_short(month), do: month |> month_name() |> String.slice(0, 3) |> String.upcase()
end

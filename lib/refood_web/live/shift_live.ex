defmodule RefoodWeb.ShiftLive do
  @moduledoc """
  Handles daily shift summary and shift displays.
  """
  use RefoodWeb, :live_view

  alias Refood.Families
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
    families = Families.list_families_by_date(date)

    assigns =
      [date: date, tv_rows: @tv_min_rows, tv_trim: 0, selected_family: nil, view_to_show: nil] ++
        families_page_assigns(families, @tv_min_rows)

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
        <h2 class="text-xl font-bold text-center">F-{family.number} – {family.name}</h2>
        <div class="flex flex-col gap-3">
          <.link
            :if={show_add_swap?(family, @date)}
            patch={"/shift/#{family.id}?new-swap"}
            class="w-full px-4 py-3 text-center border border-gray-300 rounded-lg hover:bg-gray-50"
          >
            Trocar dia
          </.link>
          <.link
            :if={show_add_absence?(family)}
            patch={"/shift/#{family.id}?new-absence"}
            class="w-full px-4 py-3 text-center border border-gray-300 rounded-lg hover:bg-gray-50"
          >
            Marcar falta
          </.link>
          <.link
            patch={"/shift/#{family.id}?loaned-items"}
            class="w-full px-4 py-3 text-center border border-gray-300 rounded-lg hover:bg-gray-50"
          >
            Gerir empréstimos
          </.link>
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
      <.family_card :for={family <- @families} family={family} date={@date} />
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

  defp family_card(assigns) do
    ~H"""
    <div
      class="relative w-full px-4 py-3 bg-white flex flex-col md:flex-row md:flex-wrap rounded-lg justify-start md:items-start gap-2 2xl:h-full 2xl:items-center 2xl:flex-nowrap"
      data-family-id={@family.id}
    >
      <button
        class="absolute inset-0 rounded-lg"
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

  defp families_page_assigns(families, tv_rows) do
    [families: families, page: 0, total_pages: tv_total_pages(families, tv_rows)]
  end

  defp schedule_next_tv_page,
    do: Process.send_after(self(), :next_tv_page, @tv_rotate_interval_ms)

  defp short_name(name) do
    case String.split(name, " ", trim: true) do
      [single] -> single
      parts -> "#{List.first(parts)} #{List.last(parts)}"
    end
  end

  defp show_add_absence?(family) do
    family.absences == []
  end

  defp show_add_swap?(family, _date) do
    family.absences == [] && Enum.empty?(family.swaps)
  end

  @impl true
  def handle_event("prev-date", _, socket) do
    prev_date = Timex.shift(socket.assigns.date, days: -1)
    families = Families.list_families_by_date(prev_date)

    assigns = [date: prev_date] ++ families_page_assigns(families, socket.assigns.tv_rows)

    {:noreply, assign(socket, assigns)}
  end

  @impl true
  def handle_event("next-date", _, socket) do
    next_date = Timex.shift(socket.assigns.date, days: 1)
    families = Families.list_families_by_date(next_date)

    assigns = [date: next_date] ++ families_page_assigns(families, socket.assigns.tv_rows)

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
            families_page_assigns(Families.list_families_by_date(date), socket.assigns.tv_rows)

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
            families_page_assigns(Families.list_families_by_date(date), socket.assigns.tv_rows)

        {:noreply, socket |> assign(assigns) |> put_flash(:info, "Troca efetuada!")}

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
      families_page_assigns(Families.list_families_by_date(date), tv_rows) ++
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
      families_page_assigns(Families.list_families_by_date(date), tv_rows) ++
        [selected_family: family_id]

    {:noreply, socket |> assign(assigns)}
  end

  @impl true
  def handle_info({:shift_updated, _event}, socket) do
    %{date: date, tv_rows: tv_rows} = socket.assigns

    assigns = families_page_assigns(Families.list_families_by_date(date), tv_rows)

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

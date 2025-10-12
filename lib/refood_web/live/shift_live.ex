defmodule RefoodWeb.ShiftLive do
  @moduledoc """
  Handles daily shift summary and shift displays.
  """
  use RefoodWeb, :live_view

  alias Refood.Families
  alias RefoodWeb.HelpQueueLive.NewHelpRequest
  alias RefoodWeb.ShiftLive.LoanedItems

  @impl true
  def mount(_params, _session, socket) do
    date = Date.utc_today()

    assigns = [
      date: date,
      families: Families.list_families_by_date(date),
      selected_family: nil,
      view_to_show: nil
    ]

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
          <.input type="date" field={@form[:to]} />
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
    <div
      id="shift-table"
      class="sm:h-full sm:overflow-y-hidden overflow-y-auto flex flex-col sm:flex-wrap items-center gap-2"
    >
      <div :if={@families == []} class="h-16 flex justify-center items-center">
        Nenhuma família para o dia.
      </div>
      <div
        :for={family <- @families}
        class="max-w-5/11 min-h-[60px] px-6 py-4 bg-white flex rounded-lg justify-start items-center relative"
      >
        <div class="text-xl font-bold w-11">F-{family.number}</div>
        <div class="text-lg pl-2 w-52">{family.name}</div>
        <div class="text-lg pl-2 w-28 flex items-center gap-3">
          <.icon name="hero-users-solid" />{family.adults} + {family.children}
        </div>
        <div class="px-2 w-100 flex items-center justify-start gap-2">
          <%= if family.restrictions do %>
            <div class="flex items-center gap-1">
              <.icon name="hero-exclamation-triangle-solid text-red-700" />
              <p class="text-red-700">{family.restrictions}</p>
            </div>
          <% else %>
            -
          <% end %>
          <div
            :if={!Enum.empty?(family.swaps)}
            class="w-25 px-6 py-1 border rounded-3xl border-green-600 text-green-600 text-center font-bold"
          >
            Troca
          </div>
          <div :for={absence <- family.absences}>
            <div
              :if={absence.warned}
              class="w-25 px-6 py-1 border rounded-3xl border-yellow-600 text-yellow-600 text-center font-bold"
            >
              Avisou
            </div>
            <div
              :if={!absence.warned}
              class="w-25 px-6 py-1 border rounded-3xl border-red-500 text-red-500 text-center font-bold"
            >
              Faltou
            </div>
          </div>
          <div
            :if={!Enum.empty?(family.unreturned_loaned_items)}
            class=" px-6 py-1 border rounded-3xl border-blue-600 text-blue-600 text-center font-bold"
          >
            Empréstimo
          </div>
        </div>
        <div class="relative absolute right-0">
          <.dropdown id={"shift-dropdown-#{family.id}"}>
            <:link :if={show_add_swap?(family, @date)} patch={"/shift/#{family.id}?new-swap"}>
              Trocar dia
            </:link>
            <:link :if={show_add_absence?(family)} patch={"/shift/#{family.id}?new-absence"}>
              Marcar falta
            </:link>
            <:link patch={"/shift/#{family.id}?loaned-items"}>
              Gerir empréstimos
            </:link>
          </.dropdown>
        </div>
      </div>
    </div>
    """
  end

  defp show_add_absence?(family) do
    family.absences == []
  end

  defp show_add_swap?(family, date) do
    family.absences == [] && Enum.empty?(family.swaps) &&
      Date.compare(date, Date.utc_today()) in [:gt, :eq]
  end

  @impl true
  def handle_event("prev-date", _, socket) do
    prev_date = Timex.shift(socket.assigns.date, days: -1)

    assigns = [
      date: prev_date,
      families: Families.list_families_by_date(prev_date)
    ]

    {:noreply, assign(socket, assigns)}
  end

  @impl true
  def handle_event("next-date", _, socket) do
    next_date = Timex.shift(socket.assigns.date, days: 1)

    assigns = [
      date: next_date,
      families: Families.list_families_by_date(next_date)
    ]

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
          base_assigns ++ [families: Families.list_families_by_date(date)]

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
        assigns = [
          view_to_show: nil,
          selected_family: nil,
          families: Families.list_families_by_date(date)
        ]

        {:noreply, socket |> assign(assigns) |> put_flash(:info, "Troca efetuada!")}

      {:error, changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  @impl true
  def handle_event("cancel-modal", _, socket) do
    socket = assign(socket, selected_family: nil, view_to_show: nil)
    {:noreply, push_patch(socket, to: "/shift")}
  end

  @impl true
  def handle_info({:help_request_created, _}, socket) do
    assigns = [selected_family: nil, view_to_show: nil]
    {:noreply, assign(socket, assigns)}
  end

  @impl true
  def handle_info({:loaned_item_added, _family_id}, socket) do
    %{date: date} = socket.assigns

    assigns = [
      families: Families.list_families_by_date(date),
      selected_family: nil,
      view_to_show: nil
    ]

    {:noreply,
     socket
     |> assign(assigns)
     |> push_patch(to: "/shift")}
  end

  @impl true
  def handle_info({:loaned_item_updated, family_id}, socket) do
    %{date: date} = socket.assigns

    assigns = [
      families: Families.list_families_by_date(date),
      selected_family: family_id
    ]

    {:noreply, socket |> assign(assigns)}
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

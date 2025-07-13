defmodule RefoodWeb.HelpQueueLive do
  @moduledoc """
  Manages the queue for help.
  """
  use RefoodWeb, :live_view

  alias Refood.Families
  alias RefoodWeb.HelpQueueLive.NewHelpRequest
  alias RefoodWeb.HelpQueueLive.ChangeQueuePosition
  alias RefoodWeb.HelpQueueLive.HelpRequestDetails

  @impl true
  def mount(_params, _session, socket) do
    assigns = [
      queue: Families.list_queue(),
      selected_family: nil,
      view_to_show: nil,
      sort: %{},
      filter: ""
    ]

    {:ok, assign(socket, assigns)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.live_component
      :if={@view_to_show == :new_request}
      module={NewHelpRequest}
      id="new-help-request"
      on_created={fn family -> send(self(), {:updated_family, family}) end}
      on_cancel={JS.push("hide-view")}
    />

    <.live_component
      :if={@view_to_show == :change_order}
      module={ChangeQueuePosition}
      id="change-queue-order"
      family={@selected_family}
      on_created={fn family -> send(self(), {:updated_family, family}) end}
      on_cancel={JS.push("hide-view")}
    />

    <.live_component
      :if={@view_to_show == :show_request_details}
      module={HelpRequestDetails}
      id="help-request-details"
      family={@selected_family}
      on_created={fn family -> send(self(), {:updated_family, family}) end}
      on_cancel={JS.push("hide-view")}
    />

    <.header>
      Lista de Espera
      <:actions>
        <.button phx-click="show-new-request">Criar pedido de ajuda</.button>
      </:actions>
    </.header>
    <div class="mt-11 bg-white rounded-xl">
      <.table id="help-queue" rows={@queue} row_click={&JS.push("show-request", value: %{id: &1.id})}>
        <:top_controls>
          <div class="flex items-center justify-between p-4">
            <.table_search_input value={@filter} on_change="on-filter" on_reset="on-reset-filter" />
          </div>
        </:top_controls>s
        <:col
          :let={family}
          id="position"
          sort={@sort[:queue_position]}
          on_sort={&on_sort(:queue_position, &1)}
          label="Posição"
        >
          <div class="flex flex-row gap-5 justify-center items-center">
            <.link phx-click="show-change-order" phx-value-id={family.id}>
              <.icon name="hero-arrows-up-down" class="h-5 w-5 hover:bg-blue-500" />
            </.link>

            {"#{family.queue_position}"}
          </div>
        </:col>
        <:col :let={family} id="family-id" sort={@sort[:id]} on_sort={&on_sort(:id, &1)} label="ID">
          {String.slice(family.id, 0, 6)}
        </:col>
        <:col :let={family} id="name" sort={@sort[:name]} on_sort={&on_sort(:name, &1)} label="Nome">
          {family.name}
        </:col>
        <:col
          :let={family}
          id="adults"
          sort={@sort[:adults]}
          on_sort={&on_sort(:adults, &1)}
          label="Adultos"
        >
          {family.adults}
        </:col>
        <:col
          :let={family}
          id="children"
          sort={@sort[:children]}
          on_sort={&on_sort(:children, &1)}
          label="Crianças"
        >
          {family.children}
        </:col>
        <:col
          :let={family}
          id="phone-number"
          sort={@sort[:phone_number]}
          on_sort={&on_sort(:phone_number, &1)}
          label="Tel."
        >
          {family.phone_number}
        </:col>
        <:col
          :let={family}
          id="email"
          sort={@sort[:email]}
          on_sort={&on_sort(:email, &1)}
          label="Email"
        >
          {family.email}
        </:col>
        <:col
          :let={family}
          id="region"
          sort={@sort[:region]}
          on_sort={&on_sort(:region, &1)}
          label="Região"
        >
          {family.address.region} / {family.address.city}
        </:col>
        <:col
          :let={family}
          id="inserted-at"
          sort={@sort[:inserted_at]}
          on_sort={&on_sort(:inserted_at, &1)}
          label="Criado em"
        >
          {family.inserted_at}
        </:col>
      </.table>
    </div>
    """
  end

  defp on_sort(col_id, sort), do: JS.push("on-sort", value: %{id: col_id, sort: sort})

  @impl true
  def handle_event("show-new-request", _, socket) do
    {:noreply, assign(socket, :view_to_show, :new_request)}
  end

  @impl true
  def handle_event("show-change-order", %{"id" => family_id}, socket) do
    assigns = [
      view_to_show: :change_order,
      selected_family: Families.get_family!(family_id)
    ]

    {:noreply, assign(socket, assigns)}
  end

  @impl true
  def handle_event("show-request", %{"id" => family_id}, socket) do
    assigns = [
      view_to_show: :show_request_details,
      selected_family: Families.get_family!(family_id)
    ]

    {:noreply, assign(socket, assigns)}
  end

  @impl true
  def handle_event("hide-view", _unsigned_params, socket) do
    {:noreply, assign(socket, :view_to_show, nil)}
  end

  @impl true
  def handle_event("on-sort", %{"id" => col_id, "sort" => sort}, socket) do
    col_id = String.to_existing_atom(col_id)
    sort = sort && String.to_existing_atom(sort)

    new_sort =
      case sort do
        nil -> %{}
        sort -> Map.new([{col_id, sort}])
      end

    assigns = [
      sort: new_sort,
      queue: sort_families(socket.assigns.queue, col_id, sort)
    ]

    {:noreply, assign(socket, assigns)}
  end

  @impl true
  def handle_event("on-filter", %{"value" => value}, socket) do
    assigns = [
      filter: value,
      queue: Families.list_queue(%{q: value})
    ]

    {:noreply, assign(socket, assigns)}
  end

  @impl true
  def handle_event("on-reset-filter", _, socket) do
    assigns = [
      filter: "",
      queue: Families.list_queue()
    ]

    {:noreply, assign(socket, assigns)}
  end

  defp sort_families(families, _key, nil), do: families
  defp sort_families(families, key, order), do: Enum.sort_by(families, &Map.get(&1, key), order)

  @impl true
  def handle_info({:updated_family, _}, socket) do
    assigns = [
      view_to_show: nil,
      queue: Families.list_queue()
    ]

    {:noreply, assign(socket, assigns)}
  end
end

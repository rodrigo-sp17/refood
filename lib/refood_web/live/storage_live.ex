defmodule RefoodWeb.StorageLive do
  @moduledoc """
  Manages a single storage with its items.
  """
  use RefoodWeb, :live_view

  alias RefoodWeb.StorageLive.ManageItems

  alias Refood.Inventory.Storages

  @impl true
  def mount(%{"id" => storage_id}, _session, socket) do
    assigns = [
      storage: Storages.get_storage!(storage_id),
      items: Storages.list_summarized_storage_items(storage_id),
      selected_product_id: nil,
      sort: %{},
      filter: ""
    ]

    {:ok, assign(socket, assigns)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.header>
      Inventário - {@storage.name}
      <:actions>
        <.link href={~p"/storages/#{@storage.id}/items/new"}>
          <.button class="bg-green-700">Adicionar Item</.button>
        </.link>
      </:actions>
    </.header>

    <.live_component
      :if={@selected_product_id}
      storage={@storage}
      product_id={@selected_product_id}
      module={ManageItems}
      id="manage-items"
      on_cancel={JS.push("deselect-product")}
    />
    <!--<.list>
        <:item title="Criado em"><%= NaiveDateTime.to_string(@storage.inserted_at) %></:item>
      </.list>-->
    <div class="mt-11 bg-white rounded-xl">
      <.table
        id="storage_items"
        rows={@items}
        row_click={&JS.push("select-product", value: %{id: &1.product_id})}
      >
        <:top_controls>
          <div class="flex items-center justify-between p-4">
            <.table_search_input value={@filter} on_change="on-filter" on_reset="on-reset-filter" />
            <.dropdown id="storage-table">
              <:link href={~p"/storages/#{@storage.id}/items/download"}>
                Exportar para Excel
              </:link>
            </.dropdown>
          </div>
        </:top_controls>
        <:col :let={item} sort={@sort[:name]} on_sort={&on_sort(:name, &1)} label="Produto">
          {item.product_name}
        </:col>
        <:col :let={item} sort={@sort[:name]} on_sort={&on_sort(:name, &1)} label="Qtd.">
          {item.quantity}
        </:col>
        <:col
          :let={item}
          sort={@sort[:expires_at]}
          on_sort={&on_sort(:expires_at, &1)}
          label="Validade Mínima"
        >
          {item.expires_at}
        </:col>
      </.table>
    </div>

    <.back navigate={~p"/storages"}>Voltar</.back>
    """
  end

  @impl true
  def handle_event("on-filter", %{"value" => value}, socket) do
    assigns = [
      filter: value,
      items: filter_items(socket.assigns.storage.id, value)
    ]

    {:noreply, assign(socket, assigns)}
  end

  @impl true
  def handle_event("on-reset-filter", _, socket) do
    assigns = [
      filter: "",
      storage: Storages.get_storage!(socket.assigns.storage.id)
    ]

    {:noreply, assign(socket, assigns)}
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
      storage: sort_storage(socket.assigns.storage, col_id, sort)
    ]

    {:noreply, assign(socket, assigns)}
  end

  @impl true
  def handle_event("select-product", %{"id" => product_id}, socket) do
    assigns = [
      selected_product_id: product_id
    ]

    {:noreply, assign(socket, assigns)}
  end

  @impl true
  def handle_event("deselect-product", _, socket) do
    assigns = [
      storage: Storages.get_storage!(socket.assigns.storage.id),
      items: Storages.list_summarized_storage_items(socket.assigns.storage.id),
      selected_product_id: nil
    ]

    {:noreply, assign(socket, assigns)}
  end

  defp filter_items(storage_id, value) do
    downcase_value = String.downcase(value)
    items = Storages.list_summarized_storage_items(storage_id)

    Enum.filter(items, fn %{product: %{name: name}} ->
      Enum.any?([name], &String.contains?(String.downcase(&1), downcase_value))
    end)
  end

  defp on_sort(col_id, sort), do: JS.push("on-sort", value: %{id: col_id, sort: sort})

  defp sort_storage(storage, _key, nil), do: storage

  defp sort_storage(storage, :name, order),
    do: %{storage | items: Enum.sort_by(storage.items, &Map.get(&1, :product).name, order)}

  defp sort_storage(storage, key, order),
    do: %{storage | items: Enum.sort_by(storage.items, &Map.get(&1, key), order)}
end

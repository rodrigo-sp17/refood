defmodule RefoodWeb.StorageLive do
  @moduledoc """
  Manages a single storage with its items.
  """
  use RefoodWeb, :live_view

  alias Refood.Inventory.Storages

  @impl true
  def mount(%{"id" => storage_id}, _session, socket) do
    assigns = [
      storage: Storages.get_storage!(storage_id),
      sort: %{}
    ]

    {:ok, assign(socket, assigns)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.header>
      Inventário - <%= @storage.name %>
      <:actions>
        <.link href={~p"/storages/#{@storage.id}/items/new"}>
          <.button class="bg-green-700">Adicionar Item</.button>
        </.link>
      </:actions>
    </.header>
    <!--<.list>
        <:item title="Criado em"><%= NaiveDateTime.to_string(@storage.inserted_at) %></:item>
      </.list>-->
    <.table id="storage_items" rows={@storage.items}>
      <:col :let={item} sort={@sort[:name]} on_sort={&on_sort(:name, &1)} label="Produto">
        <%= item.product.name %>
      </:col>
      <:col :let={item} sort={@sort[:expires_at]} on_sort={&on_sort(:expires_at, &1)} label="Validade">
        <%= item.expires_at %>
      </:col>
      <:action :let={item}>
        <.link
          phx-click="remove-item"
          phx-value-id={item.id}
          data-confirm="Tem certeza de que deseja remover o item?"
        >
          <.icon name="hero-x-mark" class="h-5 w-5 bg-red-500" />
        </.link>
      </:action>
    </.table>

    <.back navigate={~p"/storages"}>Voltar</.back>
    """
  end

  @impl true
  def handle_event("remove-item", %{"id" => item_id}, socket) do
    Storages.remove_item!(item_id)

    assigns = [
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

  defp on_sort(col_id, sort), do: JS.push("on-sort", value: %{id: col_id, sort: sort})

  defp sort_storage(storage, _key, nil), do: storage

  defp sort_storage(storage, :name, order),
    do: %{storage | items: Enum.sort_by(storage.items, &Map.get(&1, :product).name, order)}

  defp sort_storage(storage, key, order),
    do: %{storage | items: Enum.sort_by(storage.items, &Map.get(&1, key), order)}
end

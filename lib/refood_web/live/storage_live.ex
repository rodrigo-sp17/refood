defmodule RefoodWeb.StorageLive do
  @moduledoc """
  Manages a single storage with its items.
  """
  use RefoodWeb, :live_view

  alias Refood.Inventory.Storages

  @impl true
  def mount(%{"id" => storage_id}, _session, socket) do
    storage = Storages.get_storage!(storage_id)
    {:ok, assign(socket, :storage, storage)}
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
      <:col :let={item} label="Produto"><%= item.product.name %></:col>
      <:col :let={item} label="Validade"><%= item.expires_at %></:col>
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
end

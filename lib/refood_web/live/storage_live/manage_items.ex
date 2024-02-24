defmodule RefoodWeb.StorageLive.ManageItems do
  @moduledoc """
  Component that lists and manages items for a specific product.
  """
  use RefoodWeb, :live_component

  alias Refood.Inventory.Products
  alias Refood.Inventory.Storages

  @impl true
  def update(assigns, socket) do
    product = Products.get!(assigns.product_id)

    items =
      Storages.list_storage_items(
        storage_id: assigns.storage.id,
        product_id: assigns.product_id
      )

    assigns = [
      id: assigns.id,
      on_cancel: assigns.on_cancel,
      storage: assigns.storage,
      product: product,
      items: items,
      selected_items: MapSet.new()
    ]

    {:ok, assign(socket, assigns)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <RefoodWeb.StorageLive.ProductPickerComponent.search_modal show id={@id} on_cancel={@on_cancel}>
        <.header>
          <%= @product.name %>
        </.header>

        <div class="flex flex-col items-center gap-6 justify-between">
          <div class="overflow-auto max-h-[300px] min-h-[200px] w-[400px]">
            <.table id="items" rows={@items}>
              <:col :let={item}>
                <.input
                  type="checkbox"
                  name="selected_item"
                  phx-target={@myself}
                  phx-click="select-item"
                  phx-value-item_id={item.id}
                  value={true}
                  checked={MapSet.member?(@selected_items, item.id)}
                />
              </:col>
              <:col :let={item} label="Validade">
                <%= if item.expires_at, do: item.expires_at, else: "-" %>
              </:col>
            </.table>
          </div>

          <%= if MapSet.size(@selected_items) > 0 do %>
            <.button class="py-2 bg-red-500" phx-target={@myself} phx-click="remove-items">
              Remover item(s)
            </.button>
          <% else %>
            <.button class="py-2">
              Adicionar items
            </.button>
          <% end %>
        </div>
      </RefoodWeb.StorageLive.ProductPickerComponent.search_modal>
    </div>
    """
  end

  @impl true
  def handle_event("select-all", _unsigned_params, socket) do
    current_selection = socket.assigns.selected_items

    new_selection =
      if MapSet.size(current_selection) > 0 do
        MapSet.new()
      else
        MapSet.new(Enum.map(socket.assigns.items, fn item -> item.id end))
      end

    assigns = [
      selected_items: new_selection
    ]

    {:noreply, assign(socket, assigns)}
  end

  @impl true
  def handle_event("select-item", %{"item_id" => item_id} = assigns, socket) do
    current_selection = socket.assigns.selected_items

    new_selection =
      if assigns["value"] do
        MapSet.put(current_selection, item_id)
      else
        MapSet.delete(current_selection, item_id)
      end

    assigns = [
      selected_items: new_selection
    ]

    {:noreply, assign(socket, assigns)}
  end

  @impl true
  def handle_event("remove-items", _, socket) do
    Enum.each(socket.assigns.selected_items, &Storages.remove_item!(&1))

    items =
      Storages.list_storage_items(
        storage_id: socket.assigns.storage.id,
        product_id: socket.assigns.product.id
      )

    assigns = [
      items: items,
      selected_items: MapSet.new()
    ]

    {:noreply, assign(socket, assigns)}
  end
end

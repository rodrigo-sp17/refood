defmodule RefoodWeb.StorageLive.NewItemLive do
  use RefoodWeb, :live_view

  alias Refood.Inventory.Products
  alias Refood.Inventory.Product
  alias Refood.Inventory.Storages

  @impl true
  def mount(%{"id" => storage_id}, _session, socket) do
    {:ok,
     socket
     |> assign(:storage_id, storage_id)
     |> assign(:changeset, Storages.change_item())
     |> assign(:show_search_product, false)
     |> assign(:product, %Product{})}
  end

  @impl true
  def handle_event("open-search-product", %{"key" => key}, socket) do
    if key != "Tab" do
      {:noreply, assign(socket, :show_search_product, true)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("open-search-product", _, socket),
    do: {:noreply, assign(socket, :show_search_product, true)}

  def handle_event("close-search-product", _params, socket) do
    {:noreply, assign(socket, :show_search_product, false)}
  end

  def handle_event("choose-product", params, socket) do
    product = Products.get!(params["product_id"]) || %Product{}

    {:noreply,
     socket
     |> assign(:product, product)
     |> assign(:show_search_product, false)}
  end

  # def handle_event(
  #       "validate",
  #       %{"item" => item_params},
  #       socket
  #     ) do
  #   changeset =
  #     socket.assigns.changeset
  #     |> Item.changeset(item_params)
  #     |> Map.put(:action, :validate)

  #   {:noreply,
  #    socket
  #    |> assign(:changeset, changeset)}
  # end

  def handle_event("submit", %{"item" => item_params} = params, socket) do
    case Storages.add_item(
           socket.assigns.storage_id,
           item_params |> Map.put("product_id", params["product_id"])
         ) do
      {:ok, _item} ->
        {:noreply,
         socket
         |> put_flash(:info, "Item adicionado!")
         |> assign(:changeset, Storages.change_item())}

      {:error, changeset} ->
        {
          :noreply,
          assign(socket, :changeset, changeset)
        }
    end
  end
end

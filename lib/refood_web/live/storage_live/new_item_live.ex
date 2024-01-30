defmodule RefoodWeb.StorageLive.NewItemLive do
  use RefoodWeb, :live_view

  alias Refood.Inventory.Product
  alias Refood.Inventory.Storages

  @impl true
  def mount(%{"id" => storage_id}, _, socket) do
    {:ok,
     socket
     |> assign(:changeset, Storages.change_item())
     |> assign(:storage_id, storage_id)
     |> assign(:show_product_picker, true)
     |> assign(:product, %Product{})}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        Adicionar Item
      </.header>

      <.live_component
        module={RefoodWeb.StorageLive.ProductPickerComponent}
        id="product-picker"
        show={@show_product_picker}
        on_cancel={JS.push("hide-product-picker")}
      />

      <.simple_form :let={f} for={@changeset} phx-submit="submit">
        <.input
          readonly="readonly"
          label="Produto"
          phx-click="show-product-picker"
          phx-keydown="show-product-picker"
          value={@product.name}
          name="product_name"
          errors={Enum.map(f[:product_id].errors, &translate_error(&1))}
        />
        <.input hidden type="hidden" name="product_id" value={@product.id} />
        <.input type="date" label="Validade" field={f[:expires_at]} />
        <:actions>
          <.button>Adicionar Item</.button>
        </:actions>

        <.error :if={@changeset.action}>
          Oops, algo de errado aconteceu!
        </.error>
      </.simple_form>

      <.back navigate={~p"/storages/#{@storage_id}"}>Voltar</.back>
    </div>
    """
  end

  @impl true
  def handle_info({:selected_product, product}, socket) do
    {:noreply,
     socket
     |> assign(:product, product || %Product{})
     |> assign(:show_product_picker, false)}
  end

  @impl true
  def handle_event("show-product-picker", %{"key" => key}, socket) do
    if key != "Tab" do
      {:noreply, assign(socket, :show_product_picker, true)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("show-product-picker", _, socket),
    do: {:noreply, assign(socket, :show_product_picker, true)}

  def handle_event("hide-product-picker", _params, socket) do
    {:noreply, assign(socket, :show_product_picker, false)}
  end

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

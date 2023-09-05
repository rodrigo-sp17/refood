defmodule RefoodWeb.StorageLive.ProductSearchComponent do
  @moduledoc "A component that searches for Products"
  use RefoodWeb, :live_component

  alias Refood.Inventory.Products

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.search_modal :if={@show} show id={@id} on_cancel={@on_cancel}>
        <.search_input value={@query} phx-target={@myself} phx-keyup="do-search" phx-debounce="200" />
        <.results change_event={@change_event} products={@products} query={@query} />
      </.search_modal>
    </div>
    """
  end

  attr :value, :any
  attr :rest, :global

  def search_input(assigns) do
    ~H"""
    <div class="relative flex flex-row items-center space-x-2">
      <.icon name="hero-magnifying-glass" class="h-6 w-6" />
      <input
        {@rest}
        value={@value}
        type="text"
        class="h-12 flex-grow border-round border-zinc-300 focus:border-zinc-400 rounded-lg focus:ring-0 pl-3 pr-3 text-gray-800 placeholder-gray-400 text-xl "
        placeholder="Buscar produtos..."
        role="combobox"
        aria-expanded="false"
        aria-controls="options"
      />
    </div>
    """
  end

  attr :change_event, :string, default: "change"
  attr :query, :string, required: true
  attr :products, :list, required: true

  def results(assigns) do
    ~H"""
    <ul
      class="mb-2 py-2 text-sm text-gray-800 flex space-y-2 flex-col hover"
      id="options"
      role="listbox"
    >
      <li
        :if={@products == [] && String.length(@query) >= 3}
        id="option-none"
        role="option"
        tabindex="-1"
        class="cursor-default select-none rounded-md px-4 py-2 text-xl"
      >
        TODO -> registrar produto
      </li>
      <li
        :if={@products == [] && String.length(@query) < 3}
        id="option-none"
        role="option"
        tabindex="-1"
        class="cursor-default select-none rounded-md px-4 py-2 text-xl"
      >
        Nenhum produto encontrado
      </li>
      <.link
        :for={product <- @products}
        id={"product-#{product.id}"}
        phx-click={@change_event}
        phx-value-product_id={product.id}
      >
        <.result_item product={product} />
      </.link>
    </ul>
    """
  end

  attr :product, :map, required: true

  def result_item(assigns) do
    ~H"""
    <li
      class="cursor-default select-none rounded-md px-4 py-2 text-xl bg-zinc-100 hover:bg-zinc-800 hover:text-white hover:cursor-pointer flex flex-row space-x-2 items-center"
      id={"option-#{@product.id}"}
      role="option"
      tabindex="-1"
    >
      <div>
        <%= @product.name %>
        <div class="text-xs"><%= @product.id %></div>
      </div>
    </li>
    """
  end

  attr :id, :string, required: true
  attr :show, :boolean, default: false
  attr :on_cancel, JS, default: %JS{}
  slot :inner_block, required: true

  def search_modal(assigns) do
    ~H"""
    <div
      id={@id}
      phx-mounted={@show && show_modal(@id)}
      phx-remove={hide_modal(@id)}
      class="relative z-50 hidden"
    >
      <div id={"#{@id}-bg"} class="fixed inset-0 bg-zinc-50/90 transition-opacity" aria-hidden="true" />
      <div
        class="fixed inset-0 overflow-y-auto"
        aria-labelledby={"#{@id}-title"}
        aria-describedby={"#{@id}-description"}
        role="dialog"
        aria-modal="true"
        tabindex="0"
      >
        <div class="flex min-h-full justify-center">
          <div class="w-full min-h-12 max-w-3xl p-2 sm:p-4 lg:py-6">
            <.focus_wrap
              id={"#{@id}-container"}
              phx-mounted={@show && show_modal(@id)}
              phx-window-keydown={hide_modal(@on_cancel, @id)}
              phx-key="escape"
              phx-click-away={hide_modal(@on_cancel, @id)}
              class="hidden relative rounded-2xl bg-white p-2 shadow-lg shadow-zinc-700/10 ring-1 ring-zinc-700/10 transition min-h-[30vh] max-h-[50vh] overflow-y-scroll"
            >
              <div class="p-1" id={"#{@id}-content"}>
                <%= render_slot(@inner_block) %>
              </div>
            </.focus_wrap>
          </div>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def mount(socket) do
    {:ok, socket}
  end

  @impl true
  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign(:selected_product, nil)
     |> assign(:products, [])
     |> assign(:query, "")}
  end

  @impl true
  def handle_event("do-search", %{"value" => value}, socket) do
    {:noreply,
     socket
     |> assign(:query, value)
     |> assign(:products, search_products(value))}
  end

  defp search_products(""), do: []

  defp search_products(query) when is_binary(query) do
    try do
      Products.list(%{name: String.upcase(query)})
    rescue
      _ ->
        # ExqLite.Error
        []
    end
  end

  defp search_products(_), do: []
end

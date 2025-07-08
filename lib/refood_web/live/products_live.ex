defmodule RefoodWeb.ProductsLive do
  @moduledoc """
  Manages and check products to be added to storages.
  """
  use RefoodWeb, :live_view

  alias RefoodWeb.ProductsLive.EditProduct
  alias RefoodWeb.ProductsLive.NewProduct
  alias RefoodWeb.ProductsLive.ShowProduct

  alias Refood.Inventory.Products

  # TODO -> maybe make show and edit part of the same modal
  # TODO -> nice dialog

  @impl true
  def mount(_params, _session, socket) do
    view_to_show =
      case socket.assigns.live_action do
        :new -> :new_product
        :show -> :show_product
        :edit -> :edit_product
        _ -> nil
      end

    assigns = [
      products: Products.list(),
      selected_product: nil,
      view_to_show: view_to_show,
      sort: %{},
      filter: ""
    ]

    {:ok, assign(socket, assigns)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.header>
      Catálogo de Produtos
      <:actions>
        <.button phx-click="show-new-product">Novo Produto</.button>
      </:actions>
    </.header>

    <.live_component
      :if={@view_to_show == :new_product}
      module={NewProduct}
      id="new-product"
      on_created={fn product -> send(self(), {:updated_product, product}) end}
      on_cancel={JS.push("hide-view")}
    />

    <ShowProduct.render
      :if={@view_to_show == :show_product}
      id="show-product"
      product={@selected_product}
      on_cancel={JS.push("hide-view")}
    />

    <.live_component
      :if={@view_to_show == :edit_product}
      module={EditProduct}
      id="edit-product"
      product={@selected_product}
      on_updated={fn product -> send(self(), {:updated_product, product}) end}
      on_cancel={JS.push("hide-view")}
    />

    <div class="mt-11 bg-white rounded-xl">
      <.table id="products" rows={@products} row_click={&JS.push("show-product", value: %{id: &1.id})}>
        <:top_controls>
          <div class="flex items-center justify-between p-4">
            <.table_search_input value={@filter} on_change="on-filter" on_reset="on-reset-filter" />
          </div>
        </:top_controls>
        <:col :let={product} sort={@sort[:id]} on_sort={&on_sort(:id, &1)} label="ID">
          {String.slice(product.id, 0, 8)}
        </:col>
        <:col :let={product} id="name" sort={@sort[:name]} on_sort={&on_sort(:name, &1)} label="Nome">
          {product.name}
        </:col>
        <:col
          :let={product}
          sort={@sort[:inserted_at]}
          on_sort={&on_sort(:inserted_at, &1)}
          label="Inserido em"
        >
          {NaiveDateTime.to_string(product.inserted_at)}
        </:col>
        <:action :let={product}>
          <.link phx-click="show-edit-product" phx-value-id={product.id}>
            <.icon name="hero-pencil" class="h-5 w-5 hover:bg-blue-500" />
          </.link>
        </:action>
        <:action :let={product}>
          <.link
            phx-click="delete-product"
            phx-value-id={product.id}
            data-confirm="Tem certeza de que deseja remover?"
          >
            <.icon name="hero-x-mark" class="h-5 w-5 hover:bg-red-500" />
          </.link>
        </:action>
      </.table>
    </div>
    """
  end

  @impl true
  def handle_event("show-new-product", _, socket) do
    {:noreply, assign(socket, :view_to_show, :new_product)}
  end

  @impl true
  def handle_event("show-product", %{"id" => product_id}, socket) do
    assigns = [
      view_to_show: :show_product,
      selected_product: Products.get!(product_id)
    ]

    {:noreply, assign(socket, assigns)}
  end

  @impl true
  def handle_event("show-edit-product", %{"id" => product_id}, socket) do
    assigns = [
      view_to_show: :edit_product,
      selected_product: Products.get!(product_id)
    ]

    {:noreply, assign(socket, assigns)}
  end

  @impl true
  def handle_event("hide-view", _unsigned_params, socket) do
    {:noreply, assign(socket, :view_to_show, nil)}
  end

  @impl true
  def handle_event("delete-product", %{"id" => product_id}, socket) do
    {:ok, _} =
      product_id
      |> Products.get!()
      |> Products.delete()

    assigns = [
      products: Products.list()
    ]

    {:noreply, assign(socket, assigns)}
  end

  @impl true
  def handle_event("on-filter", %{"value" => value}, socket) do
    assigns = [
      filter: value,
      products: filter_products(value)
    ]

    {:noreply, assign(socket, assigns)}
  end

  @impl true
  def handle_event("on-reset-filter", _, socket) do
    assigns = [
      filter: "",
      products: Products.list()
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
      products: sort_products(socket.assigns.products, col_id, sort)
    ]

    {:noreply, assign(socket, assigns)}
  end

  defp on_sort(col_id, sort), do: JS.push("on-sort", value: %{id: col_id, sort: sort})

  defp sort_products(products, _key, nil), do: products
  defp sort_products(products, key, order), do: Enum.sort_by(products, &Map.get(&1, key), order)

  defp filter_products(value) do
    downcase_value = String.downcase(value)
    products = Products.list()

    Enum.filter(products, fn %{id: id, name: name} ->
      Enum.any?([id, name], &String.contains?(String.downcase(&1), downcase_value))
    end)
  end

  @impl true
  def handle_info({:updated_product, _}, socket) do
    assigns = [
      view_to_show: nil,
      products: Products.list()
    ]

    {:noreply, assign(socket, assigns)}
  end
end

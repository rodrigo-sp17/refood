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
      view_to_show: view_to_show
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

    <.table id="products" rows={@products} row_click={&JS.push("show-product", value: %{id: &1.id})}>
      <:col :let={product} label="ID"><%= product.id %></:col>
      <:col :let={product} label="Nome"><%= product.name %></:col>
      <:col :let={product} label="Inserido em">
        <%= NaiveDateTime.to_string(product.inserted_at) %>
      </:col>
      <:action :let={product}>
        <.link phx-click="show-edit-product" phx-value-id={product.id}>
          <.icon name="hero-pencil" class="h-5 w-5 " />
        </.link>
      </:action>
      <:action :let={product}>
        <.link
          phx-click="delete-product"
          phx-value-id={product.id}
          data-confirm="Tem certeza de que deseja remover?"
        >
          <.icon name="hero-x-mark" class="h-5 w-5 bg-red-500" />
        </.link>
      </:action>
    </.table>
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
  def handle_info({:updated_product, _}, socket) do
    assigns = [
      view_to_show: nil,
      products: Products.list()
    ]

    {:noreply, assign(socket, assigns)}
  end
end

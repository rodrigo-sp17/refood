defmodule RefoodWeb.ProductsLive.EditProduct do
  @moduledoc """
  Edits a product.
  """
  use RefoodWeb, :live_component

  alias Refood.Inventory.Products
  alias Refood.Inventory.Product

  @impl true
  def update(%{product: product} = assigns, socket) do
    updated_assigns =
      Map.merge(assigns, %{
        changeset: Product.changeset(product, %{})
      })

    {:ok, assign(socket, updated_assigns)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.modal show id={@id} on_cancel={@on_cancel}>
        <.header>
          Editar Produto <%= @product.id %>
        </.header>

        <.simple_form :let={f} for={@changeset} phx-target={@myself} phx-submit="edit-product">
          <.input field={f[:name]} label="Nome" />
          <.error :if={@changeset.action}>
            Oops, algo de errado aconteceu!
          </.error>

          <:actions>
            <.button>Salvar</.button>
          </:actions>
        </.simple_form>
      </.modal>
    </div>
    """
  end

  @impl true
  def handle_event("edit-product", %{"product" => product_attrs}, socket) do
    case Products.update(socket.assigns.product, product_attrs) do
      {:ok, updated_product} ->
        socket.assigns.on_updated.(updated_product)
        {:noreply, put_flash(socket, :info, "Produto editado!")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end
end

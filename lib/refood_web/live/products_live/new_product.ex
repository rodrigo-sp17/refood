defmodule RefoodWeb.ProductsLive.NewProduct do
  @moduledoc """
  Component that adds a new Product to the list.
  """
  use RefoodWeb, :live_component

  alias Refood.Inventory.Product
  alias Refood.Inventory.Products

  @impl true
  def mount(socket) do
    assigns = [
      changeset: Products.change(%Product{})
    ]

    {:ok, assign(socket, assigns)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <RefoodWeb.StorageLive.ProductPickerComponent.search_modal show id={@id} on_cancel={@on_cancel}>
        <.header>
          Novo Produto
          <:subtitle>
            <p>Use este formulário para registrar um novo tipo de produto.</p>
            <strong>Certifique-se de que não haja outro produto com descrição similar!</strong>
          </:subtitle>
        </.header>

        <.simple_form :let={f} for={@changeset} phx-target={@myself} phx-submit="add-product">
          <.input field={f[:name]} label="Nome" />
          <.error :if={@changeset.action}>
            Oops, algo de errado aconteceu!
          </.error>

          <:actions>
            <.button>Salvar</.button>
          </:actions>
        </.simple_form>
      </RefoodWeb.StorageLive.ProductPickerComponent.search_modal>
    </div>
    """
  end

  @impl true
  def handle_event("add-product", %{"product" => product_attrs}, socket) do
    case Products.register(product_attrs) do
      {:ok, created_product} ->
        socket.assigns.on_created.(created_product)
        {:noreply, put_flash(socket, :info, "Produto registrado!")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end
end

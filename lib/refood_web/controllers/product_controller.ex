defmodule RefoodWeb.ProductController do
  use RefoodWeb, :controller

  alias Refood.Inventory.Products
  alias Refood.Inventory.Product

  def index(conn, _params) do
    products = Products.list()
    render(conn, :index, products: products)
  end

  def new(conn, _params) do
    changeset = Products.change(%Product{})
    render(conn, :new, changeset: changeset)
  end

  def create(conn, %{"product" => product_params}) do
    case Products.register(product_params) do
      {:ok, product} ->
        conn
        |> put_flash(:info, "Produto registrado!")
        |> redirect(to: ~p"/products/#{product}")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :new, changeset: changeset)
    end
  end

  def show(conn, %{"id" => id}) do
    product = Products.get!(id)
    render(conn, :show, product: product)
  end

  def edit(conn, %{"id" => id}) do
    product = Products.get!(id)
    changeset = Products.change(product)
    render(conn, :edit, product: product, changeset: changeset)
  end

  def update(conn, %{"id" => id, "product" => product_params}) do
    product = Products.get!(id)

    case Products.update(product, product_params) do
      {:ok, product} ->
        conn
        |> put_flash(:info, "Produto atualizado!")
        |> redirect(to: ~p"/products/#{product}")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :edit, product: product, changeset: changeset)
    end
  end

  def delete(conn, %{"id" => id}) do
    product = Products.get!(id)
    {:ok, _product} = Products.delete(product)

    conn
    |> put_flash(:info, "Produto removido com successo!")
    |> redirect(to: ~p"/products")
  end
end

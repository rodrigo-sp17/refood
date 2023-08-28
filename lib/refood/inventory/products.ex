defmodule Refood.Inventory.Products do
  @moduledoc """
  Manages a product catalog.
  """

  alias Refood.Inventory.Product
  alias Refood.Repo

  def register(attrs) do
    attrs
    |> Product.changeset()
    |> Repo.insert()
  end

  def list do
    Repo.all(Product)
  end

  def get!(product_id) do
    Repo.get!(Product, product_id)
  end

  def change(product) do
    Product.changeset(product, %{})
  end

  def update(product, attrs) do
    Product.changeset(product, attrs)
    |> Repo.update()
  end

  def delete(product) do
    Repo.delete(product)
  end
end

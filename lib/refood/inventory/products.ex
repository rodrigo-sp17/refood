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

  def update(product, attrs) do
    Product.changeset(product, attrs)
    |> Repo.update()
  end
end

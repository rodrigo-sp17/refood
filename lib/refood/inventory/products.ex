defmodule Refood.Inventory.Products do
  @moduledoc """
  Manages a product catalog.
  """
  import Ecto.Query

  alias Refood.Inventory.Product
  alias Refood.Repo

  def register(attrs) do
    attrs
    |> Product.changeset()
    |> Repo.insert()
  end

  def list(params \\ %{}) do
    Product
    |> filter_name(params)
    |> Repo.all()
  end

  defp filter_name(query, %{name: name}) do
    name_query = "%#{name}%"

    query
    |> where([p], like(p.name, ^name_query))
  end

  defp filter_name(query, _), do: query

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

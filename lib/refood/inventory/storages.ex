defmodule Refood.Inventory.Storages do
  @moduledoc """
  Manages the storages.
  """
  import Ecto.Query

  alias Refood.Inventory.Item
  alias Refood.Inventory.Storage
  alias Refood.Repo

  def create(attrs) do
    attrs
    |> Storage.changeset()
    |> Repo.insert()
  end

  def change(struct) do
    Storage.changeset(struct, %{})
  end

  def list_storages do
    Repo.all(Storage)
    |> Repo.preload(items: :product)
  end

  # TODO -> test this
  def list_storage_items(opts \\ []) do
    from(item in Item)
    |> apply_filters(opts)
    |> order_by(:expires_at)
    |> Repo.all()
  end

  defp apply_filters(query, []), do: query

  defp apply_filters(query, [filter | rest]) do
    filtered_query =
      case filter do
        {:storage_id, storage_id} ->
          from(item in query, where: item.storage_id == ^storage_id)

        {:product_id, product_id} ->
          from(item in query, where: item.product_id == ^product_id)

        _ ->
          query
      end

    apply_filters(filtered_query, rest)
  end

  def list_summarized_storage_items(storage_id) do
    from(item in Item,
      inner_join: product in assoc(item, :product),
      where: item.storage_id == ^storage_id,
      group_by: [item.product_id, product.name],
      select: %{
        product_id: item.product_id,
        product_name: product.name,
        quantity: count(item.id),
        expires_at: min(item.expires_at)
      }
    )
    |> Repo.all()
  end

  def get_storage!(storage_id) when is_binary(storage_id) do
    Repo.get!(Storage, storage_id)
    |> Repo.preload(items: :product)
  end

  def change_item(struct \\ %Item{}) do
    Item.changeset(struct, %{})
  end

  def add_item(storage_id, item_attrs) do
    %Item{
      storage_id: storage_id
    }
    |> Item.add_item_changeset(item_attrs)
    |> Repo.insert()
  end

  def remove_item!(item_id) do
    Repo.get!(Item, item_id)
    |> Repo.delete!()
  end
end

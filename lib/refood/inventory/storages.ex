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

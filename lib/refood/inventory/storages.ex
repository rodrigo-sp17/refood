defmodule Refood.Inventory.Storages do
  @moduledoc """
  Manages the storages.
  """

  alias Refood.Inventory.Item
  alias Refood.Inventory.Storage
  alias Refood.Repo

  def create(attrs) do
    attrs
    |> Storage.changeset()
    |> Repo.insert()
  end

  def list do
    Repo.all(Storage)
    |> Repo.preload(:items)
  end

  def get!(storage_id) when is_binary(storage_id) do
    Repo.get!(Storage, storage_id)
    |> Repo.preload(:items)
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

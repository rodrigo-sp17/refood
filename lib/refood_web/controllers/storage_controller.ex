defmodule RefoodWeb.StorageController do
  use RefoodWeb, :controller

  alias Refood.Inventory.Storages
  alias Refood.Inventory.Storage
  alias Refood.Inventory.Item

  def index(conn, _params) do
    storages = Storages.list_storages()
    render(conn, :index, storages: storages)
  end

  def new(conn, _params) do
    changeset = Storages.change(%Storage{})
    render(conn, :new, changeset: changeset)
  end

  def create(conn, %{"storage" => storage_params}) do
    case Storages.create(storage_params) do
      {:ok, storage} ->
        conn
        |> put_flash(:info, "Inventário criado!")
        |> redirect(to: ~p"/storages/#{storage}")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :new, changeset: changeset)
    end
  end

  def show(conn, %{"id" => id}) do
    storage = Storages.get_storage!(id)
    render(conn, :show, storage: storage)
  end

  def edit(conn, %{"id" => id}) do
    storage = Storages.get_storage!(id)
    changeset = Storages.change(storage)
    render(conn, :edit, storage: storage, changeset: changeset)
  end

  def new_item(conn, %{"id" => id}) do
    storage = Storages.get_storage!(id)
    changeset = Storages.change_item(%Item{})
    render(conn, :new_item, storage: storage, changeset: changeset)
  end

  def add_item(conn, %{"item" => item_params, "id" => storage_id}) do
    case Storages.add_item(storage_id, item_params) do
      {:ok, _item} ->
        storage = Storages.get_storage!(storage_id)

        conn
        |> put_flash(:info, "Item adicionado!")
        |> redirect(to: ~p"/storages/#{storage}")

      {:error, %Ecto.Changeset{} = changeset} ->
        storage = Storages.get_storage!(storage_id)
        render(conn, :new_item, changeset: changeset, storage: storage)
    end
  end

  def remove_item(conn, %{"item_id" => item_id, "id" => storage_id}) do
    Storages.remove_item!(item_id)

    conn
    |> put_flash(:info, "Item removido!")
    |> redirect(to: ~p"/storages/#{storage_id}")
  end
end

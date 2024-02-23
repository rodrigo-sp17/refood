defmodule Refood.Inventory.StoragesTest do
  use Refood.DataCase, async: true

  alias Refood.Inventory.Storages

  describe "create" do
    test "errors if product does not exist" do
      attrs = %{
        name: "cozinha",
        items: [
          %{product_id: Ecto.UUID.generate(), expires_at: ~D[2023-11-01]}
        ]
      }

      assert {:error, _changeset} = Storages.create(attrs)
    end

    test "creates a storage w/ items" do
      %{id: product_id} = insert(:product)

      attrs = %{
        name: "cozinha",
        items: [
          %{product_id: product_id, expires_at: ~D[2023-11-01]}
        ]
      }

      assert {:ok,
              %{
                name: "cozinha",
                items: [
                  %{product_id: ^product_id}
                ]
              }} = Storages.create(attrs)
    end

    test "creates a storage without items" do
      assert {:ok, %{name: "dispensa"}} = Storages.create(%{name: "dispensa"})
    end
  end

  describe "add item" do
    test "adds an item to the storage" do
      %{id: product_id} = insert(:product)
      storage = insert(:storage)

      attrs = %{product_id: product_id, expires_at: ~D[2023-11-01]}

      assert {:ok, %{product_id: ^product_id, expires_at: expires_at}} =
               Storages.add_item(storage.id, attrs)

      assert attrs.expires_at == expires_at
    end
  end

  describe "remove item" do
    test "removes an item from the storage" do
      storage = insert(:storage)
      %{id: item_left_id} = insert(:item, storage: storage)
      item_to_remove = insert(:item, storage: storage)

      assert Storages.remove_item!(item_to_remove.id)

      assert %{items: [%{id: ^item_left_id}]} = Storages.get!(storage.id)
    end
  end

  describe "get" do
    test "returns storage w/ all items" do
      %{id: product_id} = insert(:product)
      %{id: another_product_id} = insert(:product)

      {:ok, storage} =
        Storages.create(%{
          name: "my storage",
          items: [
            %{product_id: product_id, expires_at: nil},
            %{product_id: product_id, expires_at: ~D[2023-03-02]},
            %{product_id: another_product_id, expires_at: ~D[2023-03-02]}
          ]
        })

      assert %{items: items} = Storages.get!(storage.id)

      assert length(items) == 3
    end
  end

  describe "list_summarized_storage_items" do
    test "lists storage items with their minimum expiration date" do
      storage = insert(:storage)
      product = insert(:product)
      insert(:item, product: product, storage: storage, expires_at: ~D[2020-01-01])
      insert(:item, product: product, storage: storage, expires_at: ~D[2019-01-01])
      insert(:item, product: product, storage: storage, expires_at: ~D[2022-01-01])

      assert [
               %{
                 product_name: product.name,
                 product_id: product.id,
                 quantity: 3,
                 expires_at: ~D[2019-01-01]
               }
             ] ==
               Storages.list_summarized_storage_items(storage.id)
    end
  end
end

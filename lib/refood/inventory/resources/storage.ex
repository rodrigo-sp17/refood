defmodule Refood.Inventory.Storage do
  use Ash.Resource,
    data_layer: Ash.DataLayer.Ets

  actions do
    defaults [:read]

    create :create do
      argument :items, {:array, :map}
      change manage_relationship(:items, :items, type: :create)
    end

    update :add_item do
      accept []

      argument :item, :map do
        allow_nil? false
      end

      change manage_relationship(:item, :items, type: :create)
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
    end
  end

  relationships do
    has_many :items, Refood.Inventory.Item
  end
end

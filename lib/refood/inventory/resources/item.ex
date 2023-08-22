defmodule Refood.Inventory.Item do
  use Ash.Resource,
    data_layer: Ash.DataLayer.Ets

  actions do
    defaults [:create]
  end

  attributes do
    uuid_primary_key :id

    attribute :quantity, :integer do
      allow_nil? false
    end

    attribute :expires_at, :date do
      allow_nil? true
    end
  end

  relationships do
    belongs_to :product, Refood.Inventory.Product
    belongs_to :storage, Refood.Inventory.Storage
  end
end

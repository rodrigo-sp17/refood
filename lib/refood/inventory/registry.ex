defmodule Refood.Inventory.Registry do
  use Ash.Registry,
    extensions: [
      # This extension adds helpful compile time validations
      Ash.Registry.ResourceValidations
    ]

  entries do
    entry Refood.Inventory.Product
    entry Refood.Inventory.Storage
    entry Refood.Inventory.Item
  end
end

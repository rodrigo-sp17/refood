defmodule Refood.Inventory do
  use Ash.Api

  resources do
    registry Refood.Inventory.Registry
  end
end

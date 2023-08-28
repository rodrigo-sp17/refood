defmodule Refood.Factory do
  use ExMachina.Ecto, repo: Refood.Repo

  def product_factory do
    %Refood.Inventory.Product{
      id: Ecto.UUID.generate(),
      name: sequence(:name, &"SACO PLASTICO #{&1}L")
    }
  end

  def storage_factory do
    %Refood.Inventory.Storage{
      id: Ecto.UUID.generate(),
      name: "COZINHA",
      items: []
    }
  end

  def item_factory do
    %Refood.Inventory.Item{
      product: insert(:product),
      storage: insert(:storage),
      expires_at: Enum.random([nil, Date.new!(Enum.random(1993..2050), 5, 1)])
    }
  end
end

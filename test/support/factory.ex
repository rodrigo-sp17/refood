defmodule Refood.Factory do
  use ExMachina.Ecto, repo: Refood.Repo

  def user_factory do
    %Refood.Accounts.User{
      name: sequence(:user_name, &"Jim #{&1}"),
      role: :manager,
      email: sequence(:email, &"jim#{&1}@mail.com"),
      password: "1234567890",
      hashed_password: "$2b$12$4RKfJP5waBnZNEpIUhrcXOXeCn1oi4cCOnD9wzv1mAvZRopurTZKO"
    }
  end

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

  def family_factory(attrs) do
    %Refood.Families.Family{
      number: sequence(:number, & &1),
      name: sequence("Family-"),
      adults: Enum.random(1..6),
      children: Enum.random(0..4),
      restrictions: Enum.random([nil, "- doces", "s/ frutos do mar", "vegetariano"]),
      weekdays: [:wednesday],
      address: build(:address)
    }
    |> merge_attributes(attrs)
    |> evaluate_lazy_attributes()
  end

  def address_factory do
    %Refood.Families.Address{
      city: "Porto",
      region: "Bonfim"
    }
  end

  def absence_factory do
    %Refood.Families.Absence{
      date: Date.utc_today(),
      warned: true,
      family: build(:family)
    }
  end

  def swap_factory do
    %Refood.Families.Swap{
      from: Date.utc_today(),
      to: Date.add(Date.utc_today(), 1),
      family: build(:family)
    }
  end

  def alert_factory(attrs) do
    %Refood.Families.Alert{
      type: :excessive_absences,
      dismissed_at: nil,
      family: build(:family)
    }
    |> merge_attributes(attrs)
    |> evaluate_lazy_attributes()
  end

  def loaned_item_factory(attrs) do
    %Refood.Families.LoanedItem{
      name: sequence(:loaned_item_name, &"Tupperware #{&1}"),
      quantity: Enum.random(1..3),
      loaned_at: DateTime.utc_now(),
      returned_at: nil,
      family: build(:family)
    }
    |> merge_attributes(attrs)
    |> evaluate_lazy_attributes()
  end
end

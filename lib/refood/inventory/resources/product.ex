defmodule Refood.Inventory.Product do
  use Ash.Resource,
    data_layer: AshPostgres.DataLayer

  alias Ash.Changeset

  postgres do
    table "products"

    repo Refood.Repo
  end

  code_interface do
    define_for Refood.Inventory

    define :register, action: :create
    define :read, action: :read
    define :update, action: :update
  end

  actions do
    defaults [:read, :update, :destroy]

    create :create do
      change fn changeset, _ ->
        case Changeset.get_attribute(changeset, :name) do
          nil -> changeset
          name -> Changeset.change_attribute(changeset, :name, String.upcase(name))
        end
      end
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  identities do
    identity :name, [:name]
  end
end

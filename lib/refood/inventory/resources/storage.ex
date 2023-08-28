defmodule Refood.Inventory.Storage do
  use Refood.Schema

  alias Refood.Inventory.Item

  schema "storages" do
    field :name, :string

    has_many :items, Item

    timestamps format: :utc_datetime
  end

  def changeset(schema \\ %__MODULE__{}, attrs) do
    schema
    |> cast(attrs, [:name])
    |> cast_assoc(:items)
    |> validate_required(:name)
  end
end

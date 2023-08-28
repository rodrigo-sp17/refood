defmodule Refood.Inventory.Product do
  use Refood.Schema

  schema "products" do
    field :name, :string

    timestamps format: :utc_datetime
  end

  def changeset(schema \\ %__MODULE__{}, attrs) do
    schema
    |> cast(attrs, [:name])
    |> validate_required([:name])
    |> update_change(:name, fn name ->
      String.upcase(name)
    end)
    |> unique_constraint(:name)
  end
end

defmodule Refood.Fridges.Fridge do
  use Refood.Schema

  alias Refood.Fridges.TemperatureRecord

  schema "fridges" do
    field :name, :string
    has_many :temperature_records, TemperatureRecord

    timestamps(type: :utc_datetime)
  end

  def changeset(schema \\ %__MODULE__{}, attrs) do
    schema
    |> cast(attrs, [:name])
    |> validate_required([:name])
    |> update_change(:name, &String.upcase/1)
    |> unique_constraint(:name)
  end
end

defmodule Refood.Fridges.TemperatureRecord do
  use Refood.Schema

  alias Refood.Fridges.Fridge

  schema "temperature_records" do
    field :temperature, :decimal
    field :recorded_at, :utc_datetime
    belongs_to :fridge, Fridge

    timestamps(type: :utc_datetime)
  end

  def changeset(schema \\ %__MODULE__{}, attrs) do
    schema
    |> cast(attrs, [:temperature, :recorded_at, :fridge_id])
    |> validate_required([:temperature, :recorded_at, :fridge_id])
  end
end

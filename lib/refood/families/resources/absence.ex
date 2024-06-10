defmodule Refood.Families.Absence do
  @moduledoc """
  Represents a family absence for a given day.
  """
  use Refood.Schema

  alias Refood.Families.Family

  schema "absences" do
    field :date, :date
    field :warned, :boolean
    belongs_to :family, Family

    timestamps(type: :utc_datetime)
  end

  def changeset(schema \\ %__MODULE__{}, attrs) do
    schema
    |> cast(attrs, [:date, :warned, :family_id])
    |> validate_required([:date, :warned, :family_id])
    |> foreign_key_constraint(:family_id)
    |> unique_constraint([:family_id, :date], message: "falta já marcada para o dia")
  end
end

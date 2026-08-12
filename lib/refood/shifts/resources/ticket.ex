defmodule Refood.Shifts.Ticket do
  @moduledoc """
  A family's place in the day's order ("senha"). Belongs to a shift code rather than
  to a date, so it disappears with the shift that produced it.
  """
  use Refood.Schema

  alias Refood.Families.Family
  alias Refood.Shifts.Code

  schema "shift_tickets" do
    field :position, :integer
    field :source, Ecto.Enum, values: [:family, :volunteer], default: :family

    belongs_to :shift_code, Code
    belongs_to :family, Family

    timestamps(type: :utc_datetime)
  end

  def changeset(schema \\ %__MODULE__{}, attrs) do
    schema
    |> cast(attrs, [:shift_code_id, :family_id, :position, :source])
    |> validate_required([:shift_code_id, :family_id, :position, :source])
    |> validate_number(:position, greater_than: 0)
    |> unique_constraint([:shift_code_id, :family_id])
    |> unique_constraint([:shift_code_id, :position])
    |> foreign_key_constraint(:shift_code_id)
    |> foreign_key_constraint(:family_id)
  end
end

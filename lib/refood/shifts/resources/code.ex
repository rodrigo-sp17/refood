defmodule Refood.Shifts.Code do
  @moduledoc """
  The code a family types to claim a ticket. A row here *is* an open shift: tickets
  hang off it, so closing or expiring a shift releases its numbers.
  """
  use Refood.Schema

  alias Refood.Shifts.Ticket

  schema "shift_codes" do
    field :date, :date
    field :code, :string
    field :expires_at, :utc_datetime

    has_many :tickets, Ticket, foreign_key: :shift_code_id

    timestamps(type: :utc_datetime)
  end

  def changeset(schema \\ %__MODULE__{}, attrs) do
    schema
    |> cast(attrs, [:date, :code, :expires_at])
    |> validate_required([:date, :code, :expires_at])
    |> validate_format(:code, ~r/\A\d{4}\z/)
    |> unique_constraint(:date)
  end

  def expired?(%__MODULE__{expires_at: expires_at}, now) do
    DateTime.after?(now, expires_at)
  end
end

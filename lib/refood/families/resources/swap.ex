defmodule Refood.Families.Swap do
  @moduledoc """
  Represents a day swap for families.
  """
  use Refood.Schema

  alias Refood.Families.Family

  schema "swaps" do
    field :from, :date
    field :to, :date
    # The kit was already packed on the original day and is waiting on `to`.
    field :kit_prepared, :boolean, default: false
    belongs_to :family, Family

    timestamps(type: :utc_datetime)
  end

  def changeset(swap \\ %__MODULE__{}, attrs) do
    swap
    |> cast(attrs, [:to, :from, :kit_prepared, :family_id])
    |> validate_required([:to, :from, :family_id], message: "obrigatório")
    |> foreign_key_constraint(:family_id)
    |> unique_constraint([:from, :family_id], message: "troca já efetuada para este dia")
    |> unique_constraint([:to, :family_id], message: "troca já efetuada para este dia")
  end
end

defmodule Refood.Families.Swap do
  @moduledoc """
  Represents a day swap for families.
  """
  use Refood.Schema

  alias Refood.Families.Family

  schema "swaps" do
    field :from, :date
    field :to, :date
    belongs_to :family, Family

    timestamps(type: :utc_datetime)
  end

  def changeset(swap \\ %__MODULE__{}, attrs) do
    swap
    |> cast(attrs, [:to, :from, :family_id])
    |> validate_required([:to, :from, :family_id], message: "obrigatório")
    |> foreign_key_constraint(:family_id)
    |> unique_constraint([:from, :family_id], message: "troca já efetuada para este dia")
    |> unique_constraint([:to, :family_id], message: "troca já efetuada para este dia")
  end
end

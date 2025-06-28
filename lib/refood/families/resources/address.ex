defmodule Refood.Families.Address do
  use Refood.Schema

  alias Refood.Families.Family

  schema "addresses" do
    field :line_1, :string
    field :line_2, :string
    field :region, :string
    field :city, :string
    field :zipcode, :string

    belongs_to :family, Family

    timestamps(type: :utc_datetime)
  end

  def changeset(schema \\ %__MODULE__{}, attrs) do
    schema
    |> cast(attrs, [:line_1, :line_2, :region, :city, :zipcode, :family_id])
    |> validate_required([:region, :city])
    |> unique_constraint([:family_id])
  end
end

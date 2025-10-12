defmodule Refood.Families.LoanedItem do
  use Refood.Schema

  alias Refood.Families.Family

  schema "loaned_items" do
    field :name, :string
    field :quantity, :integer, default: 1
    field :loaned_at, :utc_datetime
    field :returned_at, :utc_datetime

    belongs_to :family, Family

    timestamps(type: :utc_datetime)
  end

  @doc """
  Changeset for creating a loaned item.
  """
  def changeset(attrs) do
    %__MODULE__{}
    |> cast(attrs, [:family_id, :name, :quantity, :loaned_at])
    |> validate_required([:family_id, :name, :quantity, :loaned_at])
    |> validate_number(:quantity, greater_than: 0, message: "deve ser maior que 0")
    |> foreign_key_constraint(:family_id)
  end

  @doc """
  Changeset for updating a loaned item (e.g., marking as returned).
  """
  def update_changeset(loaned_item, attrs) do
    loaned_item
    |> cast(attrs, [:name, :quantity, :returned_at])
    |> validate_number(:quantity, greater_than: 0, message: "deve ser maior que 0")
  end

  @doc """
  Returns true if the item has been returned.
  """
  def returned?(%__MODULE__{returned_at: nil}), do: false
  def returned?(%__MODULE__{returned_at: _}), do: true
end

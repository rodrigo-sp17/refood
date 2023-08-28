defmodule Refood.Inventory.Item do
  use Refood.Schema

  alias Refood.Inventory.Product
  alias Refood.Inventory.Storage

  schema "storage_items" do
    field :expires_at, :date

    belongs_to :product, Product
    belongs_to :storage, Storage

    timestamps format: :utc_datetime
  end

  @doc false
  def changeset(struct \\ %__MODULE__{}, attrs) do
    struct
    |> cast(attrs, [:storage_id, :product_id, :expires_at])
    |> base_changeset()
  end

  def add_item_changeset(struct, attrs) do
    struct
    |> cast(attrs, [:expires_at, :product_id])
    |> base_changeset()
  end

  defp base_changeset(changeset) do
    changeset
    |> foreign_key_constraint(:product_id)
    |> foreign_key_constraint(:storage_id)
  end
end

defmodule Refood.Families.Alert do
  use Refood.Schema

  import Ecto.Changeset

  alias Refood.Families.Family

  @types [excessive_absences: "Muitas faltas"]

  @type_keys Keyword.keys(@types)

  schema "alerts" do
    field :type, Ecto.Enum, values: @type_keys
    field :dismissed_at, :utc_datetime

    belongs_to :family, Family

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(alert, attrs) do
    alert
    |> cast(attrs, [:type, :dismissed_at])
    |> validate_required([:type, :family_id])
  end

  def sanitize_types(types_list) do
    Enum.filter(types_list, &(&1 in @type_keys))
  end

  def type_to_name(key), do: Keyword.get(@types, key)

  def types, do: @type_keys
end

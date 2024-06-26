defmodule Refood.Families.Family do
  use Refood.Schema

  alias Refood.Families.Absence
  alias Refood.Families.Swap

  @weekdays [:monday, :tuesday, :wednesday, :thursday, :friday, :saturday, :sunday]

  schema "families" do
    field :number, :integer
    field :name, :string
    field :adults, :integer
    field :children, :integer, default: 0
    field :restrictions, :string

    field :weekdays, {:array, Ecto.Enum}, values: @weekdays

    has_many :absences, Absence
    has_many :swaps, Swap

    timestamps(type: :utc_datetime)
  end

  def changeset(schema \\ %__MODULE__{}, attrs) do
    schema
    |> cast(attrs, [:number, :name, :adults, :children, :restrictions, :weekdays])
    |> validate_required([:number, :name, :adults, :children, :weekdays])
    |> unique_constraint([:number])
  end

  def weekday_from_date(%Date{} = date) do
    weekday = Date.day_of_week(date)
    Enum.at(@weekdays, weekday - 1)
  end

  def scheduled_to_day?(%{weekdays: weekdays}, %Date{} = date) do
    weekday = weekday_from_date(date)
    weekday in weekdays
  end
end

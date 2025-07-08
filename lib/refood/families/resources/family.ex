defmodule Refood.Families.Family do
  use Refood.Schema

  alias Refood.Families.Address
  alias Refood.Families.Absence
  alias Refood.Families.Swap

  @weekdays [:monday, :tuesday, :wednesday, :thursday, :friday, :saturday, :sunday]

  schema "families" do
    field :number, :integer
    field :name, :string
    field :adults, :integer
    field :children, :integer, default: 0
    field :restrictions, :string

    field :phone_number, :string
    field :email, :string
    has_one :address, Address

    field :status, Ecto.Enum, values: [:queued, :active, :paused, :finished], default: :queued
    field :queue_position, :integer

    field :weekdays, {:array, Ecto.Enum}, values: @weekdays
    has_many :absences, Absence
    has_many :swaps, Swap

    timestamps(type: :utc_datetime)
  end

  def request_help(attrs) do
    %__MODULE__{}
    |> cast(attrs, [
      :name,
      :adults,
      :children,
      :restrictions,
      :phone_number,
      :email,
      :queue_position
    ])
    |> cast_assoc(:address,
      with: &Address.changeset/2,
      required: true,
      required_message: "endereço requerido"
    )
    |> validate_contact_info_required()
    |> validate_number(:adults, greater_than: 0, message: "deve ser maior que 0")
    |> validate_number(:children,
      greater_than_or_equal_to: 0,
      message: "deve ser igual ou maior que 0"
    )
    |> validate_format(:email, ~r/@/)
  end

  defp validate_contact_info_required(changeset) do
    email = get_field(changeset, :email)
    phone_number = get_field(changeset, :phone_number)

    if is_nil(email) and is_nil(phone_number) do
      message = "e-mail ou telefone requeridos"

      changeset
      |> add_error(:email, message)
      |> add_error(:phone_number, message)
    else
      changeset
    end
  end

  def activate_family(family, attrs) do
    family
    |> cast(attrs, [:number, :weekdays])
    |> validate_required([:number, :weekdays])
    |> validate_length(:weekdays, min: 1, message: "dias da semana requeridos")
    |> unique_constraint([:number], message: "número já assimilado")
    |> put_change(:queue_position, nil)
    |> put_change(:status, :active)
  end

  def changeset(schema \\ %__MODULE__{}, attrs) do
    schema
    |> cast(attrs, [
      :number,
      :name,
      :adults,
      :children,
      :restrictions,
      :weekdays,
      :phone_number,
      :email,
      :status
    ])
    |> validate_required([:name, :status, :adults, :children])
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

  def get_readable_weekdays(%{weekdays: weekdays}, type) do
    weekdays
    |> Enum.map(&weekday(&1, type))
    |> Enum.join(" | ")
  end

  defp weekday(:monday, :short), do: "Seg"
  defp weekday(:tuesday, :short), do: "Ter"
  defp weekday(:wednesday, :short), do: "Qua"
  defp weekday(:thursday, :short), do: "Qui"
  defp weekday(:friday, :short), do: "Sex"
  defp weekday(:saturday, :short), do: "Sab"
  defp weekday(:sunday, :short), do: "Dom"
end

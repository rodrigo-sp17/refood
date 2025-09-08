defmodule Refood.Families do
  @moduledoc """
  Manages families and their frequencies.
  """
  import Ecto.Query
  import Ecto.Changeset

  alias Refood.Families.Absence
  alias Refood.Families.Family
  alias Refood.Families.Swap
  alias Refood.Repo

  def change_reactivate_family(family, attrs) do
    Family.activate_family(family, attrs)
  end

  @doc """
  Moves a finished family back to active help.
  """
  def reactivate_family(family_id, attrs) do
    %{status: :finished} = family = Repo.get(Family, family_id)

    family
    |> Family.activate_family(attrs)
    |> Repo.update()
  end

  @spec list_families(map()) :: [Family.t()]
  def list_families(params \\ %{}) do
    from(f in Family,
      as: :family,
      preload: [:absences],
      where: f.status != :queued,
      order_by: [
        fragment("array_position(array['active', 'paused', 'finished'], ?)", f.status),
        f.number
      ]
    )
    |> filter_families(params)
    |> Repo.all()
  end

  defp filter_families(query, params) do
    Enum.reduce(params, query, fn
      {:q, q}, query when is_binary(q) ->
        parsed_q = "%#{q}%"

        query
        |> where(
          [family: f],
          ilike(f.name, ^parsed_q) or ilike(f.restrictions, ^parsed_q)
        )
        |> maybe_search_family_number(q)

      _, query ->
        query
    end)
  end

  defp maybe_search_family_number(query, q) do
    case Integer.parse(q) do
      {number, _} -> or_where(query, [family: f], f.number == ^number)
      _ -> query
    end
  end

  @spec list_families_by_date(Date.t()) :: any()
  def list_families_by_date(%Date{} = date) do
    weekday = Family.weekday_from_date(date)

    from(
      f in Family,
      as: :family,
      left_join: swap in assoc(f, :swaps),
      on: swap.to == ^date or swap.from == ^date,
      where: f.status == :active,
      where:
        ^weekday in f.weekdays or
          exists(from(s in Swap, where: s.family_id == parent_as(:family).id and s.to == ^date)),
      where:
        not exists(
          from(s in Swap, where: s.family_id == parent_as(:family).id and s.from == ^date)
        ),
      or_where:
        ^weekday in f.weekdays and
          exists(from(s in Swap, where: s.family_id == parent_as(:family).id and s.to == ^date)) and
          exists(from(s in Swap, where: s.family_id == parent_as(:family).id and s.from == ^date)),
      order_by: f.number,
      preload: [absences: ^from(a in Absence, where: a.date == ^date), swaps: swap]
    )
    |> Repo.all()
  end

  def change_create_family(attrs) do
    Family.changeset(%Family{}, attrs)
  end

  @doc """
  Creates a new family.
  """
  def create_family(attrs) do
    attrs
    |> change_create_family()
    |> Repo.insert()
  end

  @spec get_family!(integer()) :: Family.t()
  def get_family!(family_id),
    do: Family |> Repo.get(family_id) |> Repo.preload([:address, :absences])

  def change_update_family_details(family, attrs) do
    Family.changeset(family, attrs)
  end

  def update_family_details(family, attrs) do
    family
    |> change_update_family_details(attrs)
    |> Repo.update()
  end

  def deactivate_family(family_id) do
    family_id
    |> get_family!()
    |> Family.deactivate_family()
    |> Repo.update()
  end

  def list_absences(params) do
    query = from(a in Absence)

    params
    |> Enum.reduce(query, fn
      {:family_id, family_id}, query when is_binary(family_id) ->
        where(query, [a], a.family_id == ^family_id)

      {:date, %Date{} = date}, query ->
        where(query, [a], a.date == ^date)

      _, query ->
        query
    end)
    |> Repo.all()
  end

  def add_absence(attrs) do
    attrs
    |> Absence.changeset()
    |> Repo.insert()
  end

  @doc """
  Updates an existing absence.
  """
  def update_absence(absence_id, attrs) do
    Repo.get(Absence, absence_id)
    |> Absence.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes an existing absence.
  """
  def delete_absence(absence_id) do
    Repo.get(Absence, absence_id)
    |> Repo.delete()
  end

  def add_swap(attrs, ref_date \\ Date.utc_today()) do
    family_id = attrs["family_id"] || attrs[:family_id]
    family = Repo.get!(Family, family_id)

    attrs
    |> Swap.changeset()
    |> validate_change(:from, fn _, from ->
      if Family.scheduled_to_day?(family, from) do
        []
      else
        [from: "dia fora de escala"]
      end
    end)
    |> validate_change(:to, fn _, to ->
      if Date.before?(ref_date, to) do
        []
      else
        [to: "não é possível trocar para o passado"]
      end
    end)
    |> Repo.insert()
  end

  def swap_changeset(attrs \\ %{}), do: Swap.changeset(attrs)
end

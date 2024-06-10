defmodule Refood.Families do
  @moduledoc """
  Manages families and their frequencies.
  """
  import Ecto.Query

  alias Refood.Families.Absence
  alias Refood.Families.Family
  alias Refood.Repo

  def list_families_by_date(%Date{} = date) do
    weekday = Family.weekday_from_date(date)

    from(
      f in Family,
      as: :family,
      where: ^weekday in f.weekdays,
      order_by: f.number,
      preload: [absences: ^from(a in Absence, where: a.date == ^date)]
    )
    |> Repo.all()
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
end

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

  def change_request_help(attrs) do
    Family.request_help(attrs)
  end

  def request_help(attrs) do
    attrs
    |> change_request_help()
    |> add_latest_queue_position()
    |> Repo.insert()
  end

  def change_update_help_request(family, attrs) do
    Family.update_help_request(family, attrs)
  end

  def update_help_request(family, attrs) do
    family
    |> change_update_help_request(attrs)
    |> Repo.update()
  end

  defp add_latest_queue_position(changeset) do
    latest_position =
      Repo.one(
        from(family in Family,
          order_by: [desc_nulls_last: :queue_position],
          limit: 1,
          select: family.queue_position
        )
      )

    put_change(changeset, :queue_position, (latest_position || 0) + 1)
  end

  def list_queue(params \\ %{}) do
    from(family in Family,
      as: :family,
      join: address in assoc(family, :address),
      as: :address,
      order_by: [asc: :queue_position],
      where: family.status == :queued,
      preload: [address: address]
    )
    |> filter_queue(params)
    |> Repo.all()
  end

  defp filter_queue(query, params) do
    Enum.reduce(params, query, fn
      {:q, q}, query when is_binary(q) ->
        parsed_q = "%#{q}%"

        query
        |> where(
          [family: f, address: a],
          ilike(f.name, ^parsed_q) or ilike(f.phone_number, ^parsed_q) or
            ilike(f.email, ^parsed_q) or ilike(a.region, ^parsed_q) or ilike(a.city, ^parsed_q)
        )
        |> maybe_search_family_number(q)

      _, query ->
        query
    end)
  end

  def move_queue_position(family_id, new_position) do
    case Repo.get(Family, family_id) do
      %{queue_position: current} when is_integer(current) ->
        do_move_queue_position(family_id, current, new_position)
    end
  end

  defp do_move_queue_position(family_id, current, new) when current < new do
    base_query = from(f in Family, where: f.status == :queued)

    Repo.transact(fn ->
      Repo.update_all(from(f in base_query, where: f.id == ^family_id),
        set: [queue_position: nil]
      )

      Repo.update_all(
        from(f in base_query, where: f.queue_position > ^current and f.queue_position <= ^new),
        inc: [queue_position: -1]
      )

      Repo.update_all(from(f in base_query, where: f.id == ^family_id),
        set: [queue_position: new]
      )

      {:ok, Repo.get(Family, family_id)}
    end)
  end

  defp do_move_queue_position(family_id, current, new) when new < current do
    base_query = from(f in Family, where: f.status == :queued)

    Repo.transact(fn ->
      Repo.update_all(from(f in base_query, where: f.id == ^family_id),
        set: [queue_position: nil]
      )

      Repo.update_all(
        from(f in base_query, where: f.queue_position >= ^new and f.queue_position < ^current),
        inc: [queue_position: 1]
      )

      Repo.update_all(from(f in base_query, where: f.id == ^family_id),
        set: [queue_position: new]
      )

      {:ok, Repo.get(Family, family_id)}
    end)
  end

  defp do_move_queue_position(family_id, _, _), do: {:ok, Repo.get(Family, family_id)}

  def activate_family(family_id, attrs) do
    Repo.transact(fn ->
      with {:ok, family} <- do_activate_family(family_id, attrs) do
        reorder_queue()
        {:ok, family}
      end
    end)
  end

  defp do_activate_family(family_id, attrs) do
    Repo.get(Family, family_id)
    |> Family.activate_family(attrs)
    |> Repo.update()
  end

  defp reorder_queue do
    query = from(f in Family, where: f.status == :queued)
    Repo.update_all(query, inc: [queue_position: -1])
  end

  def list_families(params \\ %{}) do
    from(f in Family,
      as: :family,
      left_join: absences in assoc(f, :absences),
      as: :absences,
      preload: [absences: absences]
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

  @spec get_family!(integer()) :: Family.t()
  def get_family!(family_id), do: Family |> Repo.get(family_id) |> Repo.preload(:address)

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

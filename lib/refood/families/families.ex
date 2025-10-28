defmodule Refood.Families do
  @moduledoc """
  Manages families and their frequencies.
  """
  import Ecto.Query
  import Ecto.Changeset

  alias Refood.Families.Absence
  alias Refood.Families.Family
  alias Refood.Families.Swap
  alias Refood.Families.Alert
  alias Refood.Families.LoanedItem
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
      preload: [:absences, :active_alerts],
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
      preload: [
        absences: ^from(a in Absence, where: a.date == ^date),
        swaps: swap,
        unreturned_loaned_items: []
      ]
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
  def get_family!(family_id) do
    Family
    |> Repo.get(family_id)
    |> Repo.preload([
      :address,
      :absences,
      :swaps,
      :active_alerts,
      :loaned_items,
      :unreturned_loaned_items
    ])
  end

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

  @doc """
  Adds an absence to a Family.
  """
  def add_absence(attrs) do
    with {:ok, absence} <- do_add_absence(attrs) do
      maybe_raise_excessive_absences_alert(absence.family_id)
      {:ok, absence}
    end
  end

  defp do_add_absence(attrs) do
    attrs
    |> Absence.changeset()
    |> Repo.insert()
  end

  defp maybe_raise_excessive_absences_alert(family_id) do
    query =
      from(absence in Absence,
        left_join:
          alert in subquery(active_or_last_dismissed_alert_query(family_id, :excessive_absences)),
        on: true,
        where: absence.family_id == ^family_id,
        where: not absence.warned,
        where: is_nil(alert.id) or absence.date > alert.dismissed_at
      )

    absences_count = Repo.aggregate(query, :count)

    if absences_count >= 3 do
      raise_alert(family_id, :excessive_absences)
    else
      :noop
    end
  end

  defp active_or_last_dismissed_alert_query(family_id, type) do
    from(alert in Alert,
      where: alert.family_id == ^family_id and alert.type == ^type,
      order_by: [desc_nulls_first: :dismissed_at],
      limit: 1
    )
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
      if Date.after?(ref_date, to) do
        [to: "não é possível trocar para o passado"]
      else
        []
      end
    end)
    |> Repo.insert()
  end

  def swap_changeset(attrs \\ %{}), do: Swap.changeset(attrs)

  @doc """
  Deletes a swap.
  """
  def delete_swap(swap_id) do
    Repo.get(Swap, swap_id)
    |> Repo.delete()
  end

  @doc """
  Raises an alert for a Family.
  """
  def raise_alert(family_id, alert_type) do
    %Alert{family_id: family_id}
    |> Alert.changeset(%{type: alert_type})
    |> Repo.insert(
      conflict_target: {:unsafe_fragment, "(family_id, type) WHERE dismissed_at IS NULL"},
      on_conflict: {:replace, [:updated_at]},
      returning: true
    )
  end

  @doc """
  Dismisses alerts for a Family, if active.
  """
  def dismiss_alerts(family_id, alert_types, dismissed_at \\ DateTime.utc_now())
      when is_binary(family_id) and is_list(alert_types) do
    filtered_types = Alert.sanitize_types(alert_types)

    {count, nil} =
      from(a in Alert,
        where: a.family_id == ^family_id and a.type in ^filtered_types and is_nil(a.dismissed_at)
      )
      |> Repo.update_all(set: [dismissed_at: dismissed_at])

    {:ok, count}
  end

  @doc """
  Returns the changeset for registering a contact.
  """
  def change_register_contact(attrs) do
    types = %{
      last_contacted_at: :utc_datetime,
      notes: :string,
      alerts_to_dismiss: {:array, Ecto.ParameterizedType.init(Ecto.Enum, values: Alert.types())}
    }

    {%{}, types}
    |> cast(attrs, [:last_contacted_at, :notes, :alerts_to_dismiss])
    |> validate_required([:last_contacted_at])
  end

  @doc """
  Registers a new contact for a Family.
  """
  def register_contact(family, attrs) do
    valid_attrs =
      attrs
      |> change_register_contact()
      |> apply_action!(:insert)

    family_attrs = Map.take(valid_attrs, [:last_contacted_at, :notes])
    alerts_to_dismiss = Map.get(valid_attrs, :alerts_to_dismiss, [])

    with {:ok, updated_family} <- update_family_details(family, family_attrs),
         {:ok, _} <- dismiss_alerts(family.id, alerts_to_dismiss) do
      {:ok, updated_family}
    end
  end

  @doc """
  Returns a changeset for adding a loaned item.
  """
  def change_add_loaned_item(attrs \\ %{}) do
    LoanedItem.changeset(attrs)
  end

  @doc """
  Adds a loaned item to a Family.
  """
  def add_loaned_item(attrs) do
    attrs
    |> change_add_loaned_item()
    |> Repo.insert()
  end

  @doc """
  Marks a loaned item as returned.
  """
  def mark_loaned_item_as_returned(loaned_item_id, returned_at \\ DateTime.utc_now()) do
    Repo.get(LoanedItem, loaned_item_id)
    |> LoanedItem.update_changeset(%{returned_at: returned_at})
    |> Repo.update()
  end

  @doc """
  Deletes a loaned item.
  """
  def delete_loaned_item(loaned_item_id) do
    Repo.get(LoanedItem, loaned_item_id)
    |> Repo.delete()
  end
end

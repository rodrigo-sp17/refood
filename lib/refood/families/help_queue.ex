defmodule Refood.Families.HelpQueue do
  @moduledoc """
  Manages families in the help queue.
  """

  import Ecto.Query
  import Ecto.Changeset

  alias Refood.Families
  alias Refood.Families.Family
  alias Refood.Repo

  def change_request_help(attrs) do
    Family.request_help(attrs)
  end

  @doc """
  Requests help for a family.
  """
  def request_help(attrs) do
    attrs
    |> change_request_help()
    |> add_latest_queue_position()
    |> Repo.insert()
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

  def change_update_help_request(family, attrs) do
    Family.update_help_request(family, attrs)
  end

  @doc """
  Updates a help request for a family.
  """
  def update_help_request(family, attrs) do
    family
    |> change_update_help_request(attrs)
    |> Repo.update()
  end

  @doc """
  Lists all families in the help queue.
  """
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

  defp maybe_search_family_number(query, q) do
    case Integer.parse(q) do
      {number, _} -> or_where(query, [family: f], f.number == ^number)
      _ -> query
    end
  end

  @doc """
  Moves a family in the help queue to a new position.
  """
  def move_queue_position(family_id, new_position) when new_position > 0 do
    case Repo.get(Family, family_id) do
      %{status: :queued, queue_position: current} when is_integer(current) ->
        do_move_queue_position(family_id, current, new_position)
    end
  end

  def move_queue_position(_, _), do: {:error, "Posição inválida"}

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

  def change_activate_family(family, attrs) do
    Family.activate_family(family, attrs)
  end

  @doc """
  Moves a family on the help queue to active help.
  """
  def activate_family(family_id, attrs) do
    family = Repo.get(Family, family_id)
    activate_changeset = Family.activate_family(family, attrs)

    Repo.transact(fn ->
      with {:ok, updated_family} <- Repo.update(activate_changeset) do
        reorder_queue(family.queue_position)
        {:ok, updated_family}
      end
    end)
  end

  defp reorder_queue(removed_position) do
    query = from(f in Family, where: f.status == :queued and f.queue_position > ^removed_position)
    Repo.update_all(query, inc: [queue_position: -1])
  end

  @doc """
  Removes a family from the help queue.
  """
  def remove_from_queue(family_id) do
    %{status: :queued} = family = Families.get_family!(family_id)
    remove_from_queue_changeset = Family.deactivate_family(family)

    Repo.transact(fn ->
      with {:ok, removed} <- Repo.update(remove_from_queue_changeset) do
        reorder_queue(family.queue_position)
        {:ok, removed}
      end
    end)
  end

  @doc """
  Re-enqueues a family.
  """
  def move_to_queue(family_id) do
    family_id
    |> Families.get_family!()
    |> Family.move_to_queue()
    |> add_latest_queue_position()
    |> Repo.update()
  end
end

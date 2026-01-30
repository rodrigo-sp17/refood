defmodule Refood.Families.HelpQueue do
  @moduledoc """
  Manages families in the help queue.
  """

  import Ecto.Query

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
    |> Repo.insert()
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
  Lists all families in the help queue, ordered by help_requested_at (oldest first).
  """
  def list_queue(params \\ %{}) do
    from(family in Family,
      as: :family,
      join: address in assoc(family, :address),
      as: :address,
      order_by: [asc: :help_requested_at],
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

  def change_activate_family(family, attrs) do
    Family.activate_family(family, attrs)
  end

  @doc """
  Moves a family on the help queue to active help.
  """
  def activate_family(family_id, attrs) do
    family = Repo.get(Family, family_id)
    activate_changeset = Family.activate_family(family, attrs)
    Repo.update(activate_changeset)
  end

  @doc """
  Removes a family from the help queue.
  """
  def remove_from_queue(family_id) do
    %{status: :queued} = family = Families.get_family!(family_id)
    remove_from_queue_changeset = Family.deactivate_family(family)
    Repo.update(remove_from_queue_changeset)
  end

  @doc """
  Re-enqueues a family.
  """
  def move_to_queue(family_id) do
    family_id
    |> Families.get_family!()
    |> Family.move_to_queue()
    |> Repo.update()
  end
end

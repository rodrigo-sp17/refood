defmodule Refood.Shifts do
  @moduledoc """
  Manages the daily ticket order ("senhas") families claim on arrival.

  A shift is opened by a volunteer, which mints a 4-digit code families type on the
  public claim page. That code row *is* the shift: tickets reference it, so closing
  the shift or reopening it releases every number for reuse, and there is no history
  to clean up.

  Expiry is deliberately weaker than closing. When the code's TTL lapses the shift
  stops accepting new claims, but its queue stays visible - the families are still
  standing in that order holding those numbers, and silently emptying the screen
  mid-service would lose the ordering irrecoverably. Only an explicit close or
  reopen discards tickets.
  """
  import Ecto.Query

  alias Refood.Families
  alias Refood.Repo
  alias Refood.Shifts.Code
  alias Refood.Shifts.Ticket

  @default_ttl_hours 4

  ## Shift lifecycle

  @doc """
  Opens a shift for `date`, minting a fresh code.

  Discards any previous shift for that date along with its tickets, so numbering
  restarts at 1. Also purges shifts whose codes have expired, on any date - the
  queue is deliberately ephemeral, so nothing accumulates.
  """
  def open_shift(date \\ Date.utc_today()) do
    now = DateTime.utc_now(:second)

    result =
      Repo.transaction(fn ->
        # Refuse to reopen a shift that is already running. Opening throws away the
        # existing tickets, so two volunteers both tapping "Abrir fila" would
        # silently wipe the queue and invalidate the code already on the whiteboard.
        if get_open_shift(date), do: Repo.rollback(:already_open)

        purge_expired(now)
        Repo.delete_all(from(c in Code, where: c.date == ^date))

        %{date: date, code: generate_code(), expires_at: DateTime.add(now, ttl_hours(), :hour)}
        |> Code.changeset()
        |> Repo.insert()
        |> case do
          {:ok, code} -> code
          {:error, changeset} -> Repo.rollback(changeset)
        end
      end)

    with {:ok, _code} <- result, do: broadcast(:shift_opened)
    result
  end

  @doc """
  Replaces the digits of an open shift's code, leaving its tickets untouched.

  This is the response to a leaked code: it must not cost the shift its ordering,
  which is why it updates in place rather than opening a new shift.
  """
  def rotate_code(date \\ Date.utc_today()) do
    case get_open_shift(date) do
      nil ->
        {:error, :shift_closed}

      %Code{} = code ->
        with {:ok, code} <- code |> Code.changeset(%{code: generate_code()}) |> Repo.update() do
          broadcast(:code_rotated)
          {:ok, code}
        end
    end
  end

  @doc """
  Closes the shift for `date`, discarding its tickets and freeing the numbers.
  """
  def close_shift(date \\ Date.utc_today()) do
    {count, _} = Repo.delete_all(from(c in Code, where: c.date == ^date))
    broadcast(:shift_closed)
    {:ok, count}
  end

  @doc """
  Returns the shift for `date` whether or not its code has expired, or nil once it
  has been closed.

  Expiry stops new claims but deliberately does not hide the queue: families are
  still standing in that order holding those numbers, so the ordering must survive
  until a volunteer explicitly reopens or closes the shift.
  """
  def get_shift(date \\ Date.utc_today()) do
    Repo.one(from(c in Code, where: c.date == ^date))
  end

  @doc """
  Returns the shift for `date` only while its code is still valid, or nil when none
  is open or it has expired. This is the gate for claiming and for showing the code.
  """
  def get_open_shift(date \\ Date.utc_today()) do
    now = DateTime.utc_now(:second)

    Repo.one(from(c in Code, where: c.date == ^date and c.expires_at > ^now))
  end

  @doc """
  Whether `date` has a shift whose code has run out but whose queue is still shown.
  """
  def shift_expired?(date \\ Date.utc_today()) do
    get_shift(date) != nil and get_open_shift(date) == nil
  end

  @doc """
  Returns whether `code` matches the open shift for `date`.
  """
  def valid_code?(code, date \\ Date.utc_today())

  def valid_code?(code, date) when is_binary(code) do
    case get_open_shift(date) do
      nil -> false
      %Code{code: expected} -> Plug.Crypto.secure_compare(String.trim(code), expected)
    end
  end

  def valid_code?(_code, _date), do: false

  defp purge_expired(now) do
    Repo.delete_all(from(c in Code, where: c.expires_at <= ^now))
  end

  defp generate_code do
    :crypto.strong_rand_bytes(4)
    |> :binary.decode_unsigned()
    |> rem(10_000)
    |> Integer.to_string()
    |> String.pad_leading(4, "0")
  end

  defp ttl_hours do
    Application.get_env(:refood, :shift_code_ttl_hours, @default_ttl_hours)
  end

  ## Tickets

  @doc """
  Returns `%{family_id => position}` for the shift on `date`, or `%{}` when there is
  none. Follows the shift rather than the code's validity, so an expired shift keeps
  showing the order families are queued in. Callers can rely on this to keep dates
  without a shift queue-free without doing any date checks of their own.
  """
  def list_ticket_positions(date \\ Date.utc_today()) do
    case get_shift(date) do
      nil ->
        %{}

      %Code{id: code_id} ->
        from(t in Ticket, where: t.shift_code_id == ^code_id, select: {t.family_id, t.position})
        |> Repo.all()
        |> Map.new()
    end
  end

  @doc """
  Families that may still claim a ticket on `date`: those scheduled for the shift
  (honouring swaps in both directions) minus those already marked absent.
  """
  def list_claimable_families(date \\ Date.utc_today()) do
    date
    |> Families.list_families_by_date()
    |> Enum.filter(&(&1.absences == []))
  end

  @doc """
  Finds a family eligible to claim on `date` by its number, or nil.

  Callers on the public page must not distinguish "no such family" from "not
  scheduled today" in what they show the user, or the page becomes an oracle for
  enumerating family numbers.
  """
  def get_claimable_family(number, date \\ Date.utc_today()) when is_integer(number) do
    date
    |> list_claimable_families()
    |> Enum.find(&(&1.number == number))
  end

  @doc """
  Claims the next ticket for a family.

  Idempotent: a family that already holds a ticket for the shift gets it back rather
  than a second number. Fails with `:shift_expired` once the code's TTL has lapsed
  and `:shift_closed` when there is no shift at all.
  """
  def claim_ticket(family_id, date \\ Date.utc_today(), source \\ :family) do
    with {:ok, %Code{} = code} <- fetch_open_shift(date),
         :ok <- validate_claimable(family_id, date) do
      do_claim(code, family_id, source)
    end
  end

  @doc """
  Returns the family's ticket for the shift on `date`, if any. Works on an expired
  shift too, so a volunteer can still revoke a wrongly issued senha.
  """
  def get_ticket(family_id, date \\ Date.utc_today()) do
    # Cast first: family_id arrives straight from a phx-value, and a non-UUID string
    # would raise Ecto.Query.CastError and take the calling LiveView down.
    with {:ok, family_id} <- Ecto.UUID.cast(family_id),
         %Code{id: code_id} <- get_shift(date) do
      find_ticket(code_id, family_id)
    else
      _ -> nil
    end
  end

  @doc """
  Deletes a ticket, freeing its holder to claim again.

  Leaves a gap in the numbering rather than renumbering: the families still waiting
  have already been told their number, so shifting them would be worse than a gap.
  """
  def delete_ticket(ticket_id) do
    case Repo.get(Ticket, ticket_id) do
      nil ->
        {:error, :not_found}

      ticket ->
        with {:ok, ticket} <- Repo.delete(ticket) do
          broadcast(:ticket_deleted)
          {:ok, ticket}
        end
    end
  end

  defp fetch_open_shift(date) do
    case get_open_shift(date) do
      nil -> {:error, if(get_shift(date), do: :shift_expired, else: :shift_closed)}
      code -> {:ok, code}
    end
  end

  defp validate_claimable(family_id, date) do
    scheduled = Families.list_families_by_date(date)

    case Enum.find(scheduled, &(&1.id == family_id)) do
      nil -> {:error, :not_scheduled}
      %{absences: [_ | _]} -> {:error, :absent}
      _ -> :ok
    end
  end

  # The advisory lock serialises number allocation for one shift, so two families
  # tapping at the same instant cannot both read the same max position. It is
  # transaction-scoped, so it releases on commit or rollback without any cleanup.
  defp do_claim(%Code{id: code_id}, family_id, source) do
    result =
      Repo.transaction(fn ->
        Repo.query!("SELECT pg_advisory_xact_lock(hashtext($1))", [code_id])

        case find_ticket(code_id, family_id) do
          %Ticket{} = existing ->
            {:existing, existing}

          nil ->
            %{
              shift_code_id: code_id,
              family_id: family_id,
              position: next_position(code_id),
              source: source
            }
            |> Ticket.changeset()
            |> Repo.insert()
            |> case do
              {:ok, ticket} -> {:claimed, ticket}
              {:error, changeset} -> Repo.rollback(changeset)
            end
        end
      end)

    case result do
      {:ok, {:claimed, ticket}} ->
        broadcast(:ticket_claimed)
        {:ok, ticket}

      {:ok, {:existing, ticket}} ->
        {:ok, ticket}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp find_ticket(code_id, family_id) do
    Repo.one(from(t in Ticket, where: t.shift_code_id == ^code_id and t.family_id == ^family_id))
  end

  defp next_position(code_id) do
    Repo.one(from(t in Ticket, where: t.shift_code_id == ^code_id, select: max(t.position)))
    |> Kernel.||(0)
    |> Kernel.+(1)
  end

  defp broadcast(event) do
    Phoenix.PubSub.broadcast(Refood.PubSub, "shift_updates", {:shift_updated, event})
  end
end

defmodule Refood.ShiftsTest do
  use Refood.DataCase, async: true

  import Ecto.Query

  alias Refood.Repo
  alias Refood.Shifts
  alias Refood.Shifts.Code
  alias Refood.Shifts.Ticket

  # list_families_by_date/1 keys off weekdays, and the family factory defaults to
  # [:wednesday], so every test pins a date to a Wednesday to stay deterministic.
  @wednesday ~D[2026-08-12]

  defp active_family(attrs \\ []) do
    insert(:family, Keyword.merge([status: :active, weekdays: [:wednesday]], attrs))
  end

  defp expire(%Code{} = code) do
    code
    |> Ecto.Changeset.change(
      expires_at: DateTime.utc_now() |> DateTime.add(-1, :hour) |> DateTime.truncate(:second)
    )
    |> Repo.update!()
  end

  describe "open_shift/1" do
    test "mints a 4-digit code that expires in 4 hours by default" do
      {:ok, code} = Shifts.open_shift(@wednesday)

      assert code.code =~ ~r/\A\d{4}\z/
      assert code.date == @wednesday

      expected = DateTime.utc_now() |> DateTime.add(4, :hour)
      assert_in_delta DateTime.to_unix(code.expires_at), DateTime.to_unix(expected), 5
    end

    test "refuses to reopen a shift that is already running" do
      family = active_family()
      {:ok, code} = Shifts.open_shift(@wednesday)
      {:ok, ticket} = Shifts.claim_ticket(family.id, @wednesday)

      # Opening discards tickets, so a second volunteer tapping "Abrir fila" must not
      # silently wipe the queue or invalidate the code already on the whiteboard.
      assert Shifts.open_shift(@wednesday) == {:error, :already_open}

      assert Shifts.get_open_shift(@wednesday).code == code.code
      assert Repo.get(Ticket, ticket.id)
    end

    test "reopening after expiry discards the old tickets so numbering restarts" do
      family = active_family()
      {:ok, code} = Shifts.open_shift(@wednesday)
      {:ok, first} = Shifts.claim_ticket(family.id, @wednesday)
      assert first.position == 1

      expire(code)
      {:ok, _} = Shifts.open_shift(@wednesday)

      assert Repo.get(Ticket, first.id) == nil
      assert {:ok, %{position: 1}} = Shifts.claim_ticket(family.id, @wednesday)
    end

    test "purges expired shifts on other dates along with their tickets" do
      family = active_family()
      {:ok, stale} = Shifts.open_shift(@wednesday)
      {:ok, ticket} = Shifts.claim_ticket(family.id, @wednesday)
      expire(stale)

      {:ok, _} = Shifts.open_shift(Date.add(@wednesday, 7))

      assert Repo.get(Code, stale.id) == nil
      assert Repo.get(Ticket, ticket.id) == nil
    end
  end

  describe "get_open_shift/1 and valid_code?/2" do
    test "there is no open shift until one is opened" do
      assert Shifts.get_open_shift(@wednesday) == nil
      refute Shifts.valid_code?("1234", @wednesday)
    end

    test "an expired shift is not open and its code stops validating" do
      {:ok, code} = Shifts.open_shift(@wednesday)
      assert Shifts.valid_code?(code.code, @wednesday)

      expire(code)

      assert Shifts.get_open_shift(@wednesday) == nil
      refute Shifts.valid_code?(code.code, @wednesday)
    end

    test "a valid code is rejected on a different date" do
      {:ok, code} = Shifts.open_shift(@wednesday)

      refute Shifts.valid_code?(code.code, Date.add(@wednesday, 1))
    end

    test "rejects the wrong code and non-binary input" do
      {:ok, code} = Shifts.open_shift(@wednesday)
      wrong = if code.code == "0000", do: "1111", else: "0000"

      refute Shifts.valid_code?(wrong, @wednesday)
      refute Shifts.valid_code?(nil, @wednesday)
    end

    test "close_shift/1 closes the shift" do
      {:ok, code} = Shifts.open_shift(@wednesday)

      assert {:ok, 1} = Shifts.close_shift(@wednesday)

      assert Shifts.get_open_shift(@wednesday) == nil
      refute Shifts.valid_code?(code.code, @wednesday)
    end
  end

  describe "rotate_code/1" do
    test "replaces the code but preserves the queue" do
      families = for _ <- 1..3, do: active_family()
      {:ok, old} = Shifts.open_shift(@wednesday)
      for f <- families, do: {:ok, _} = Shifts.claim_ticket(f.id, @wednesday)

      {:ok, new} = Shifts.rotate_code(@wednesday)

      refute new.code == old.code
      refute Shifts.valid_code?(old.code, @wednesday)
      assert Shifts.valid_code?(new.code, @wednesday)

      positions = Shifts.list_ticket_positions(@wednesday)
      assert Enum.map(families, &positions[&1.id]) == [1, 2, 3]
    end

    test "errors when no shift is open" do
      assert Shifts.rotate_code(@wednesday) == {:error, :shift_closed}
    end
  end

  describe "close_shift/1 releases the numbers" do
    test "tickets are discarded and numbering restarts on reopen" do
      families = for _ <- 1..3, do: active_family()
      {:ok, _} = Shifts.open_shift(@wednesday)
      for f <- families, do: {:ok, _} = Shifts.claim_ticket(f.id, @wednesday)

      {:ok, _} = Shifts.close_shift(@wednesday)

      assert Shifts.list_ticket_positions(@wednesday) == %{}
      assert Repo.all(from(t in Ticket, where: t.family_id in ^Enum.map(families, & &1.id))) == []

      {:ok, _} = Shifts.open_shift(@wednesday)
      assert {:ok, %{position: 1}} = Shifts.claim_ticket(hd(families).id, @wednesday)
    end
  end

  describe "no queue outside an open shift" do
    test "list_ticket_positions/1 is empty for past, future and unopened dates" do
      assert Shifts.list_ticket_positions(@wednesday) == %{}
      assert Shifts.list_ticket_positions(Date.add(@wednesday, 7)) == %{}
      assert Shifts.list_ticket_positions(Date.add(@wednesday, -7)) == %{}
    end

    test "an expired shift keeps showing its queue but accepts no new claims" do
      [queued, late] = for _ <- 1..2, do: active_family()
      {:ok, code} = Shifts.open_shift(@wednesday)
      {:ok, ticket} = Shifts.claim_ticket(queued.id, @wednesday)

      expire(code)

      # The families are still standing in that order holding those numbers, so the
      # ordering must survive expiry - only an explicit close or reopen discards it.
      assert Shifts.list_ticket_positions(@wednesday) == %{queued.id => 1}
      assert Shifts.get_ticket(queued.id, @wednesday).id == ticket.id

      # But the code is dead, so nobody new gets in.
      assert Shifts.claim_ticket(late.id, @wednesday) == {:error, :shift_expired}
      refute Shifts.valid_code?(code.code, @wednesday)
      assert Shifts.get_open_shift(@wednesday) == nil
      assert Shifts.shift_expired?(@wednesday)
    end

    test "closing an expired shift still discards its queue" do
      family = active_family()
      {:ok, code} = Shifts.open_shift(@wednesday)
      {:ok, _} = Shifts.claim_ticket(family.id, @wednesday)
      expire(code)

      {:ok, _} = Shifts.close_shift(@wednesday)

      assert Shifts.list_ticket_positions(@wednesday) == %{}
      assert Shifts.get_shift(@wednesday) == nil
    end

    test "a volunteer can still revoke a senha after expiry" do
      family = active_family()
      {:ok, code} = Shifts.open_shift(@wednesday)
      {:ok, ticket} = Shifts.claim_ticket(family.id, @wednesday)
      expire(code)

      assert {:ok, _} = Shifts.delete_ticket(ticket.id)
      assert Shifts.list_ticket_positions(@wednesday) == %{}
    end

    test "claiming is refused when no shift is open" do
      family = active_family()

      assert Shifts.claim_ticket(family.id, @wednesday) == {:error, :shift_closed}
      assert Shifts.claim_ticket(family.id, Date.add(@wednesday, 7)) == {:error, :shift_closed}
    end
  end

  describe "claim_ticket/3" do
    setup do
      {:ok, code} = Shifts.open_shift(@wednesday)
      %{code: code}
    end

    test "allocates positions in claim order" do
      [a, b, c] = for _ <- 1..3, do: active_family()

      assert {:ok, %{position: 1}} = Shifts.claim_ticket(a.id, @wednesday)
      assert {:ok, %{position: 2}} = Shifts.claim_ticket(b.id, @wednesday)
      assert {:ok, %{position: 3}} = Shifts.claim_ticket(c.id, @wednesday)
    end

    test "is idempotent and consumes no position on repeat" do
      [a, b] = for _ <- 1..2, do: active_family()

      {:ok, first} = Shifts.claim_ticket(a.id, @wednesday)
      {:ok, again} = Shifts.claim_ticket(a.id, @wednesday)

      assert again.id == first.id
      assert again.position == 1
      assert {:ok, %{position: 2}} = Shifts.claim_ticket(b.id, @wednesday)
    end

    test "records the source" do
      family = active_family()

      assert {:ok, %{source: :volunteer}} =
               Shifts.claim_ticket(family.id, @wednesday, :volunteer)
    end

    test "rejects a family not scheduled for the day" do
      family = active_family(weekdays: [:monday])

      assert Shifts.claim_ticket(family.id, @wednesday) == {:error, :not_scheduled}
    end

    test "rejects an inactive family" do
      family = insert(:family, status: :paused, weekdays: [:wednesday])

      assert Shifts.claim_ticket(family.id, @wednesday) == {:error, :not_scheduled}
    end

    test "rejects a family already marked absent" do
      family = active_family()
      insert(:absence, family: family, date: @wednesday)

      assert Shifts.claim_ticket(family.id, @wednesday) == {:error, :absent}
    end

    test "accepts a family swapped into the day" do
      family = active_family(weekdays: [:monday])
      insert(:swap, family: family, from: Date.add(@wednesday, -2), to: @wednesday)

      assert {:ok, %{position: 1}} = Shifts.claim_ticket(family.id, @wednesday)
    end

    test "rejects a family swapped out of the day" do
      family = active_family()
      insert(:swap, family: family, from: @wednesday, to: Date.add(@wednesday, 1))

      assert Shifts.claim_ticket(family.id, @wednesday) == {:error, :not_scheduled}
    end
  end

  describe "delete_ticket/1" do
    test "frees the family to claim again, leaving a gap in the numbering" do
      [a, b] = for _ <- 1..2, do: active_family()
      {:ok, _} = Shifts.open_shift(@wednesday)
      {:ok, first} = Shifts.claim_ticket(a.id, @wednesday)
      {:ok, _} = Shifts.claim_ticket(b.id, @wednesday)

      assert {:ok, _} = Shifts.delete_ticket(first.id)
      assert Shifts.list_ticket_positions(@wednesday) == %{b.id => 2}

      assert {:ok, %{position: 3}} = Shifts.claim_ticket(a.id, @wednesday)
    end

    test "errors for an unknown ticket" do
      assert Shifts.delete_ticket(Ecto.UUID.generate()) == {:error, :not_found}
    end
  end

  describe "list_claimable_families/1" do
    test "excludes families already marked absent" do
      {:ok, _} = Shifts.open_shift(@wednesday)
      present = active_family()
      absent = active_family()
      insert(:absence, family: absent, date: @wednesday)

      ids = @wednesday |> Shifts.list_claimable_families() |> Enum.map(& &1.id)

      assert ids == [present.id]
    end
  end
end

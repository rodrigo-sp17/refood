defmodule Refood.ShiftsConcurrencyTest do
  @moduledoc """
  Verifies that concurrent claims never collide on a position.

  This has to run unboxed: under the SQL sandbox every process shares the owner's
  single connection, so claims would serialise there and the advisory lock would
  never actually be exercised. Unboxed writes are committed for real, so the test
  works on a date far outside any other test's range and cleans up after itself.
  """
  use Refood.DataCase, async: false

  import Ecto.Query

  alias Ecto.Adapters.SQL.Sandbox
  alias Refood.Repo
  alias Refood.Shifts
  alias Refood.Shifts.Code
  alias Refood.Shifts.Ticket

  # A Wednesday, matching the family factory's default weekday.
  @date ~D[2099-12-30]
  @claimers 20

  test "concurrent claims allocate each position exactly once" do
    on_exit(fn ->
      Sandbox.unboxed_run(Repo, fn ->
        Repo.delete_all(from(c in Code, where: c.date == ^@date))
        Repo.delete_all(from(f in Refood.Families.Family, where: f.name == "concurrency-probe"))
      end)
    end)

    families =
      Sandbox.unboxed_run(Repo, fn ->
        Repo.delete_all(from(c in Code, where: c.date == ^@date))
        {:ok, _} = Shifts.open_shift(@date)

        for _ <- 1..@claimers do
          insert(:family,
            name: "concurrency-probe",
            status: :active,
            weekdays: [:wednesday],
            number: nil
          )
        end
      end)

    results =
      families
      |> Task.async_stream(
        fn family ->
          Sandbox.unboxed_run(Repo, fn -> Shifts.claim_ticket(family.id, @date) end)
        end,
        max_concurrency: @claimers,
        timeout: 30_000
      )
      |> Enum.map(fn {:ok, result} -> result end)

    assert Enum.all?(results, &match?({:ok, %Ticket{}}, &1))

    positions = Enum.map(results, fn {:ok, ticket} -> ticket.position end)
    assert Enum.sort(positions) == Enum.to_list(1..@claimers)

    # And the same holds when read back, not just in what each claim returned.
    stored = Sandbox.unboxed_run(Repo, fn -> Shifts.list_ticket_positions(@date) end)
    assert stored |> Map.values() |> Enum.sort() == Enum.to_list(1..@claimers)
  end
end

defmodule Refood.Families.HelpQueueTest do
  use Refood.DataCase, async: true

  alias Refood.Families.HelpQueue

  describe "request_help/1" do
    test "creates a family with help_requested_at timestamp" do
      insert(:family, name: "Joao", status: :queued, help_requested_at: ~U[2025-01-01T00:00:00Z])
      insert(:family, name: "Maria", status: :queued, help_requested_at: ~U[2025-01-02T00:00:00Z])
      insert(:family, name: "Abreu", status: :active)

      attrs = %{
        address: %{
          region: "Bonfim",
          city: "Porto",
          zipcode: "12345"
        },
        phone_number: "+351123456789",
        email: "jane@gmail.com",
        adults: 2,
        children: 0,
        name: "Jane Silva",
        help_requested_at: ~U[2025-01-03T00:00:00Z],
        speaks_portuguese: false
      }

      assert {:ok, family} = HelpQueue.request_help(attrs)

      assert %{
               id: _,
               number: nil,
               status: :queued,
               address: %{
                 region: "Bonfim",
                 city: "Porto",
                 zipcode: "12345"
               },
               phone_number: "+351123456789",
               email: "jane@gmail.com",
               adults: 2,
               children: 0,
               name: "Jane Silva",
               weekdays: [],
               help_requested_at: ~U[2025-01-03T00:00:00Z],
               speaks_portuguese: false
             } = family |> Repo.reload() |> Repo.preload(:address)
    end

    test "error if no contact info" do
      attrs = %{
        address: %{
          region: "Bonfim",
          city: "Porto",
          zipcode: "12345"
        },
        adults: 2,
        children: 0,
        name: "Jane Silva"
      }

      assert {:error, changeset} = HelpQueue.request_help(attrs)

      assert %{email: [_], phone_number: [_]} = errors_on(changeset)
    end

    test "error if no address info" do
      attrs = %{
        phone_number: "+351123456789",
        email: "jane@gmail.com",
        adults: 2,
        children: 0,
        name: "Jane Silva",
        help_requested_at: ~U[2025-01-01T00:00:00Z]
      }

      assert {:error, changeset} = HelpQueue.request_help(attrs)

      assert %{address: ["endereço requerido"]} == errors_on(changeset)
    end
  end

  describe "list_queue" do
    test "lists the queue of families ordered by help_requested_at (oldest first)" do
      insert(:family, status: :queued, help_requested_at: ~U[2025-01-03T00:00:00Z])
      insert(:family, status: :queued, help_requested_at: ~U[2025-01-01T00:00:00Z])
      insert(:family, status: :queued, help_requested_at: ~U[2025-01-02T00:00:00Z])
      insert(:family, status: :active)

      assert [
               %{help_requested_at: ~U[2025-01-01T00:00:00Z], address: %{city: _}},
               %{help_requested_at: ~U[2025-01-02T00:00:00Z], address: %{city: _}},
               %{help_requested_at: ~U[2025-01-03T00:00:00Z], address: %{city: _}}
             ] = HelpQueue.list_queue()
    end
  end

  describe "activate_family" do
    test "activates a family to a specific number" do
      %{id: family_id} =
        insert(:family, status: :queued, number: nil, help_requested_at: ~U[2025-01-01T00:00:00Z])

      insert(:family, status: :queued, number: nil, help_requested_at: ~U[2025-01-02T00:00:00Z])
      insert(:family, status: :queued, number: nil, help_requested_at: ~U[2025-01-03T00:00:00Z])
      insert(:family, status: :active, number: 6)

      attrs = %{
        number: 7,
        weekdays: [:monday, :tuesday]
      }

      assert {:ok, family} = HelpQueue.activate_family(family_id, attrs)

      assert %{number: 7, weekdays: [:monday, :tuesday], status: :active} = family
    end

    test "errors if number is already activated to a different family" do
      %{id: family_id} =
        insert(:family, status: :queued, number: nil, help_requested_at: ~U[2025-01-01T00:00:00Z])

      active_family = insert(:family, status: :active, number: 6)

      attrs = %{
        number: 6,
        weekdays: [:monday, :tuesday]
      }

      assert {:error, changeset} =
               HelpQueue.activate_family(family_id, attrs)

      assert errors_on(changeset) == %{number: ["número já assimilado"]}

      assert Repo.reload(active_family).number == 6
    end

    test "errors if no weekdays" do
      %{id: family_id} =
        insert(:family,
          status: :queued,
          weekdays: nil,
          help_requested_at: ~U[2025-01-01T00:00:00Z]
        )

      attrs = %{
        number: 6,
        weekdays: []
      }

      assert {:error, changeset} = HelpQueue.activate_family(family_id, attrs)

      assert errors_on(changeset) == %{weekdays: ["dias da semana requeridos"]}
    end

    test "swaps number if its free and family is already activated" do
      %{id: family_id} =
        insert(:family, status: :active, number: 6, weekdays: [:wednesday])

      attrs = %{number: 7}

      assert {:ok, family} = HelpQueue.activate_family(family_id, attrs)

      assert %{number: 7, weekdays: [:wednesday]} = family
    end
  end

  describe "remove_from_queue" do
    test "removes a family from the queue" do
      %{id: family_id} =
        insert(:family, status: :queued, number: nil, help_requested_at: ~U[2025-01-01T00:00:00Z])

      assert {:ok, family} = HelpQueue.remove_from_queue(family_id)

      assert %{status: :finished} = family
    end
  end

  describe "move_to_queue" do
    test "moves an active family back to the queue" do
      family = insert(:family, status: :active, number: 6)
      insert(:family, status: :queued, help_requested_at: ~U[2025-01-01T00:00:00Z])
      insert(:family, status: :queued, help_requested_at: ~U[2025-01-02T00:00:00Z])

      assert {:ok, updated_family} = HelpQueue.move_to_queue(family.id)

      assert updated_family.status == :queued
      assert is_nil(updated_family.number)
    end

    test "moves a finished family back to the queue" do
      family = insert(:family, status: :finished)

      assert {:ok, updated_family} = HelpQueue.move_to_queue(family.id)

      assert updated_family.status == :queued
      assert is_nil(updated_family.number)
    end
  end
end

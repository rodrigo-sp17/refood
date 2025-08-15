defmodule Refood.Families.HelpQueueTest do
  use Refood.DataCase, async: true

  alias Refood.Families.HelpQueue

  describe "request_help/1" do
    test "creates a family and assigns latest queue position" do
      insert(:family, name: "Joao", status: :queued, queue_position: 1)
      insert(:family, name: "Maria", status: :queued, queue_position: 2)
      insert(:family, name: "Abreu", status: :active, queue_position: nil)

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
        help_requested_at: ~U[2025-01-01T00:00:00Z],
        speaks_portuguese: false
      }

      assert {:ok, family} = HelpQueue.request_help(attrs)

      assert %{
               id: _,
               number: nil,
               status: :queued,
               queue_position: 3,
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
               weekdays: nil,
               help_requested_at: ~U[2025-01-01T00:00:00Z],
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
    test "lists the queue of families waiting for help" do
      insert(:family, status: :queued, queue_position: 1)
      insert(:family, status: :queued, queue_position: 3)
      insert(:family, status: :queued, queue_position: 2)
      insert(:family, status: :active, queue_position: nil)

      assert [
               %{queue_position: 1, address: %{city: _}},
               %{queue_position: 2, address: %{city: _}},
               %{queue_position: 3, address: %{city: _}}
             ] = HelpQueue.list_queue()
    end
  end

  describe "move_queue_position/2" do
    test "moves the position up in queue" do
      family_1 = insert(:family, status: :queued, queue_position: 1)
      family_2 = insert(:family, status: :queued, queue_position: 2)
      family_3 = insert(:family, status: :queued, queue_position: 3)
      family_4 = insert(:family, status: :queued, queue_position: 4)
      family_5 = insert(:family, status: :queued, queue_position: 5)
      active_family = insert(:family, status: :active, queue_position: nil)

      assert {:ok, %{queue_position: 4}} = HelpQueue.move_queue_position(family_2.id, 4)

      assert Repo.reload(family_1).queue_position == 1
      assert Repo.reload(family_3).queue_position == 2
      assert Repo.reload(family_4).queue_position == 3
      assert Repo.reload(family_2).queue_position == 4
      assert Repo.reload(family_5).queue_position == 5
      assert is_nil(Repo.reload(active_family).queue_position)
    end

    test "moves the position down in queue" do
      family_1 = insert(:family, status: :queued, queue_position: 1)
      family_2 = insert(:family, status: :queued, queue_position: 2)
      family_3 = insert(:family, status: :queued, queue_position: 3)
      family_4 = insert(:family, status: :queued, queue_position: 4)
      family_5 = insert(:family, status: :queued, queue_position: 5)
      active_family = insert(:family, status: :active, queue_position: nil)

      assert {:ok, %{queue_position: 2}} = HelpQueue.move_queue_position(family_4.id, 2)

      assert Repo.reload(family_1).queue_position == 1
      assert Repo.reload(family_4).queue_position == 2
      assert Repo.reload(family_2).queue_position == 3
      assert Repo.reload(family_3).queue_position == 4
      assert Repo.reload(family_5).queue_position == 5
      assert is_nil(Repo.reload(active_family).queue_position)
    end

    test "moves to the first position" do
      family_1 = insert(:family, status: :queued, queue_position: 1)
      family_2 = insert(:family, status: :queued, queue_position: 2)
      family_3 = insert(:family, status: :queued, queue_position: 3)
      family_4 = insert(:family, status: :queued, queue_position: 4)
      family_5 = insert(:family, status: :queued, queue_position: 5)
      active_family = insert(:family, status: :active, queue_position: nil)

      assert {:ok, %{queue_position: 1}} = HelpQueue.move_queue_position(family_2.id, 1)

      assert Repo.reload(family_1).queue_position == 2
      assert Repo.reload(family_2).queue_position == 1
      assert Repo.reload(family_3).queue_position == 3
      assert Repo.reload(family_4).queue_position == 4
      assert Repo.reload(family_5).queue_position == 5
      assert is_nil(Repo.reload(active_family).queue_position)
    end

    test "error if moving to position 0" do
      _family_1 = insert(:family, status: :queued, queue_position: 1)
      family_2 = insert(:family, status: :queued, queue_position: 2)

      assert {:error, _} = HelpQueue.move_queue_position(family_2.id, 0)
    end

    test "moves from the first position" do
      family_1 = insert(:family, status: :queued, queue_position: 1)
      family_2 = insert(:family, status: :queued, queue_position: 2)
      family_3 = insert(:family, status: :queued, queue_position: 3)
      family_4 = insert(:family, status: :queued, queue_position: 4)
      family_5 = insert(:family, status: :queued, queue_position: 5)
      active_family = insert(:family, status: :active, queue_position: nil)

      assert {:ok, %{queue_position: 4}} = HelpQueue.move_queue_position(family_1.id, 4)

      assert Repo.reload(family_1).queue_position == 4
      assert Repo.reload(family_2).queue_position == 1
      assert Repo.reload(family_3).queue_position == 2
      assert Repo.reload(family_4).queue_position == 3
      assert Repo.reload(family_5).queue_position == 5
      assert is_nil(Repo.reload(active_family).queue_position)
    end
  end

  describe "activate_family" do
    test "activates a family to a specific number" do
      %{id: family_id} = insert(:family, status: :queued, number: nil, queue_position: 1)
      family_2 = insert(:family, status: :queued, number: nil, queue_position: 2)
      family_3 = insert(:family, status: :queued, number: nil, queue_position: 3)
      active_family = insert(:family, status: :active, number: 6, queue_position: nil)

      attrs = %{
        number: 7,
        weekdays: [:monday, :tuesday]
      }

      assert {:ok, family} = HelpQueue.activate_family(family_id, attrs)

      assert %{number: 7, weekdays: [:monday, :tuesday], queue_position: nil, status: :active} =
               family

      assert Repo.reload(family_2).queue_position == 1
      assert Repo.reload(family_3).queue_position == 2
      assert is_nil(Repo.reload(active_family).queue_position)
    end

    test "reoders the queue covering the gap left by the family" do
      family_1 = insert(:family, status: :queued, number: nil, queue_position: 1)
      %{id: family_id} = insert(:family, status: :queued, number: nil, queue_position: 2)
      family_3 = insert(:family, status: :queued, number: nil, queue_position: 3)

      attrs = %{
        number: 7,
        weekdays: [:monday, :tuesday]
      }

      assert {:ok, family} = HelpQueue.activate_family(family_id, attrs)

      assert %{number: 7, weekdays: [:monday, :tuesday], queue_position: nil} = family

      assert Repo.reload(family_1).queue_position == 1
      assert Repo.reload(family_3).queue_position == 2
    end

    test "errors if number is already activated to a different family" do
      %{id: family_id} = insert(:family, status: :queued, number: nil, queue_position: 1)
      active_family = insert(:family, status: :active, number: 6, queue_position: nil)

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
      %{id: family_id} = insert(:family, status: :queued, weekdays: nil, queue_position: 1)

      attrs = %{
        number: 6,
        weekdays: []
      }

      assert {:error, changeset} = HelpQueue.activate_family(family_id, attrs)

      assert errors_on(changeset) == %{weekdays: ["dias da semana requeridos"]}
    end

    test "swaps number if its free and family is already activated" do
      %{id: family_id} =
        insert(:family, status: :active, number: 6, weekdays: [:wednesday], queue_position: 1)

      attrs = %{number: 7}

      assert {:ok, family} = HelpQueue.activate_family(family_id, attrs)

      assert %{number: 7, weekdays: [:wednesday], queue_position: nil} = family
    end
  end

  describe "remove_from_queue" do
    test "removes a family from the queue, reodering remaining ones" do
      %{id: family_id} = insert(:family, status: :queued, number: nil, queue_position: 1)
      family_2 = insert(:family, status: :queued, number: nil, queue_position: 2)
      family_3 = insert(:family, status: :queued, number: nil, queue_position: 3)

      assert {:ok, family} = HelpQueue.remove_from_queue(family_id)

      assert %{status: :finished, queue_position: nil} = family

      assert Repo.reload(family_2).queue_position == 1
      assert Repo.reload(family_3).queue_position == 2
    end

    test "removes from the middle of the queue" do
      family_1 = insert(:family, status: :queued, number: nil, queue_position: 1)
      %{id: family_id} = insert(:family, status: :queued, number: nil, queue_position: 2)
      family_3 = insert(:family, status: :queued, number: nil, queue_position: 3)

      assert {:ok, family} = HelpQueue.remove_from_queue(family_id)

      assert %{status: :finished, queue_position: nil} = family

      assert Repo.reload(family_1).queue_position == 1
      assert Repo.reload(family_3).queue_position == 2
    end
  end

  describe "move_to_queue" do
    test "moves an active family back to the queue" do
      family = insert(:family, status: :active, number: 6, queue_position: nil)
      insert(:family, status: :queued, queue_position: 1)
      insert(:family, status: :queued, queue_position: 2)

      assert {:ok, updated_family} = HelpQueue.move_to_queue(family.id)

      assert updated_family.status == :queued
      assert updated_family.queue_position == 3
      assert is_nil(updated_family.number)
    end

    test "moves a finished family back to the queue" do
      family = insert(:family, status: :finished, queue_position: nil)

      assert {:ok, updated_family} = HelpQueue.move_to_queue(family.id)

      assert updated_family.status == :queued
      assert updated_family.queue_position == 1
      assert is_nil(updated_family.number)
    end
  end
end

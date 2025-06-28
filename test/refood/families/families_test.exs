defmodule Refood.FamiliesTest do
  use Refood.DataCase, async: true

  alias Refood.Families

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
        name: "Jane Silva"
      }

      assert {:ok, family} = Families.request_help(attrs)

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
               weekdays: nil
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

      assert {:error, changeset} = Families.request_help(attrs)

      assert %{email: [_], phone_number: [_]} = errors_on(changeset)
    end

    test "error if no address info" do
      attrs = %{
        phone_number: "+351123456789",
        email: "jane@gmail.com",
        adults: 2,
        children: 0,
        name: "Jane Silva"
      }

      assert {:error, changeset} = Families.request_help(attrs)

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
             ] = Families.list_queue()
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

      assert {:ok, %{queue_position: 4}} = Families.move_queue_position(family_2.id, 4)

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

      assert {:ok, %{queue_position: 2}} = Families.move_queue_position(family_4.id, 2)

      assert Repo.reload(family_1).queue_position == 1
      assert Repo.reload(family_4).queue_position == 2
      assert Repo.reload(family_2).queue_position == 3
      assert Repo.reload(family_3).queue_position == 4
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

      assert {:ok, family} = Families.activate_family(family_id, attrs)

      assert %{number: 7, weekdays: [:monday, :tuesday], queue_position: nil} = family

      assert Repo.reload(family_2).queue_position == 1
      assert Repo.reload(family_3).queue_position == 2
      assert is_nil(Repo.reload(active_family).queue_position)
    end

    test "errors if number is already activated to a different family" do
      %{id: family_id} = insert(:family, status: :queued, number: nil, queue_position: 1)
      active_family = insert(:family, status: :active, number: 6, queue_position: nil)

      attrs = %{
        number: 6,
        weekdays: [:monday, :tuesday]
      }

      assert {:error, changeset} =
               Families.activate_family(family_id, attrs)

      assert errors_on(changeset) == %{number: ["número já assimilado"]}

      assert Repo.reload(active_family).number == 6
    end

    test "errors if no weekdays" do
      %{id: family_id} = insert(:family, status: :queued, weekdays: nil, queue_position: 1)

      attrs = %{
        number: 6,
        weekdays: []
      }

      assert {:error, changeset} = Families.activate_family(family_id, attrs)

      assert errors_on(changeset) == %{weekdays: ["dias da semana requeridos"]}
    end

    test "swaps number if its free and family is already activated" do
      %{id: family_id} =
        insert(:family, status: :active, number: 6, weekdays: [:wednesday], queue_position: 1)

      attrs = %{number: 7}

      assert {:ok, family} = Families.activate_family(family_id, attrs)

      assert %{number: 7, weekdays: [:wednesday], queue_position: nil} = family
    end
  end

  describe "list_families" do
    test "lists families if they exist" do
      _f1 = insert(:family, name: "Joao", weekdays: [:monday, :tuesday])
      _f2 = insert(:family, name: "Maria", weekdays: [:thursday, :friday])
      f3 = insert(:family, name: "Abreu", weekdays: [:tuesday, :wednesday, :thursday])
      insert(:absence, family: f3)

      assert result = Families.list_families()
      assert length(result) == 3

      assert [_] = Enum.find(result, &(&1.name == "Abreu")).absences
    end
  end

  describe "list_families_by_date/1" do
    setup do
      f1 = insert(:family, name: "Joao", weekdays: [:monday, :tuesday])
      f2 = insert(:family, name: "Maria", weekdays: [:thursday, :friday])
      insert(:absence, family: f2, date: ~D[2024-06-11])
      f3 = insert(:family, name: "Abreu", weekdays: [:tuesday, :wednesday, :thursday])
      insert(:absence, family: f3, date: ~D[2024-06-11])
      insert(:absence, family: f3, date: ~D[2024-06-10])

      %{families: [f1, f2, f3]}
    end

    test "lists families for the same weekday" do
      tue_families = Families.list_families_by_date(~D[2024-06-11])
      assert Enum.map(tue_families, & &1.name) |> Enum.sort() == ["Abreu", "Joao"]

      wed_families = Families.list_families_by_date(~D[2024-06-12])
      assert Enum.map(wed_families, & &1.name) |> Enum.sort() == ["Abreu"]

      thu_families = Families.list_families_by_date(~D[2024-06-13])
      assert Enum.map(thu_families, & &1.name) |> Enum.sort() == ["Abreu", "Maria"]
    end

    test "lists families with their day absences, if any" do
      families = Families.list_families_by_date(~D[2024-06-11])

      abreu_family = Enum.find(families, &(&1.name == "Abreu"))
      assert [%{date: ~D[2024-06-11]}] = abreu_family.absences

      joao_family = Enum.find(families, &(&1.name == "Joao"))
      assert [] = joao_family.absences
    end

    test "returns empty list if no families match" do
      assert [] == Families.list_families_by_date(~D[2024-06-15])
    end

    test "returns swapped families for the day" do
      saturday = ~D[2024-06-08]
      sunday = ~D[2024-06-09]
      monday = ~D[2024-06-10]
      no_swap_family = insert(:family, weekdays: [:sunday])

      %{family: in_swap_family} =
        insert(:swap, family: build(:family, weekdays: [:monday]), to: sunday, from: monday)

      %{family: out_swap_family} = insert(:swap, to: saturday, from: sunday)

      assert families = Families.list_families_by_date(sunday)

      assert length(families) == 2
      assert [] = Enum.find(families, &(&1.id == no_swap_family.id)).swaps
      assert [_] = Enum.find(families, &(&1.id == in_swap_family.id)).swaps

      assert [sat_family] = Families.list_families_by_date(saturday)
      assert sat_family.id == out_swap_family.id

      monday_families = Families.list_families_by_date(monday)
      refute Enum.find(monday_families, &(&1.id == in_swap_family.id))
    end

    test "returns only the swap relative for the day" do
      saturday = ~D[2024-06-08]
      sunday = ~D[2024-06-09]
      family = insert(:family, weekdays: [:saturday])

      swap = insert(:swap, family: family, from: saturday, to: sunday)
      unrelated_swap = insert(:swap, family: family, from: ~D[2024-06-15], to: ~D[2024-06-16])

      assert [%{swaps: swaps}] = Families.list_families_by_date(sunday)

      assert Enum.find(swaps, &(&1.id == swap.id))
      refute Enum.find(swaps, &(&1.id == unrelated_swap.id))
    end
  end

  describe "list_absences/1" do
    test "list all absences for a family" do
      family = insert(:family)
      absence_1 = insert(:absence, date: ~D[2024-06-15], family: family)
      absence_2 = insert(:absence, date: ~D[2024-06-16], family: family)
      other_absence = insert(:absence)

      assert absences = Families.list_absences(%{family_id: family.id})

      assert Enum.find(absences, &(&1.id == absence_1.id))
      assert Enum.find(absences, &(&1.id == absence_2.id))
      refute Enum.find(absences, &(&1.id == other_absence.id))
    end

    test "lists all absences for a date" do
      date = ~D[2024-06-15]
      absence_1 = insert(:absence, date: date)
      absence_2 = insert(:absence, date: date)
      other_absence = insert(:absence, date: ~D[2024-06-16])

      assert absences = Families.list_absences(%{date: date})

      assert Enum.find(absences, &(&1.id == absence_1.id))
      assert Enum.find(absences, &(&1.id == absence_2.id))
      refute Enum.find(absences, &(&1.id == other_absence.id))
    end
  end

  describe "add_absence/1" do
    test "creates an absence when valid attrs" do
      family = insert(:family)

      attrs = %{
        family_id: family.id,
        warned: false,
        date: ~D[2024-06-10]
      }

      assert {:ok, absence} = Families.add_absence(attrs)

      assert absence.family_id == family.id
      assert absence.date == ~D[2024-06-10]
      refute absence.warned
    end

    test "errors if family does not exist" do
      attrs = %{
        family_id: Ecto.UUID.generate(),
        warned: true,
        date: ~D[2024-06-10]
      }

      assert {:error, changeset} = Families.add_absence(attrs)

      assert errors_on(changeset) == %{family_id: ["does not exist"]}
    end

    test "errors if adding duplicate absence to same day" do
      family = insert(:family)

      attrs = %{
        family_id: family.id,
        warned: false,
        date: ~D[2024-06-10]
      }

      assert {:ok, _absence} = Families.add_absence(attrs)
      assert {:error, changeset} = Families.add_absence(attrs)

      assert errors_on(changeset) == %{family_id: ["falta já marcada para o dia"]}
    end

    test "errors when invalid attrs" do
      attrs = %{}

      assert {:error, changeset} = Families.add_absence(attrs)

      assert errors_on(changeset) == %{
               family_id: ["can't be blank"],
               date: ["can't be blank"],
               warned: ["can't be blank"]
             }
    end
  end

  describe "add_swap/1" do
    test "creates swap if valid attrs" do
      family = insert(:family, weekdays: [:wednesday])

      attrs = %{
        family_id: family.id,
        from: ~D[2024-05-15],
        to: ~D[2024-05-17]
      }

      assert {:ok, swap} = Families.add_swap(attrs, ~D[2024-05-01])
      assert swap.family_id == family.id
    end

    test "errors if swapping from same day for same family" do
      ref_date = ~D[2024-05-01]
      family_1 = insert(:family, weekdays: [:wednesday])
      family_2 = insert(:family, weekdays: [:wednesday])

      attrs = %{
        family_id: family_1.id,
        from: ~D[2024-05-15],
        to: ~D[2024-05-17]
      }

      assert {:ok, _family} = Families.add_swap(%{attrs | family_id: family_2.id}, ref_date)
      assert {:ok, _family} = Families.add_swap(attrs, ref_date)
      assert {:error, changeset} = Families.add_swap(%{attrs | to: ~D[2024-05-18]}, ref_date)

      assert errors_on(changeset) == %{
               from: ["troca já efetuada para este dia"]
             }
    end

    test "error if swapping out of a not-scheduled day" do
      family = insert(:family, weekdays: [:wednesday])

      attrs = %{
        family_id: family.id,
        from: ~D[2024-06-27],
        to: ~D[2024-06-28]
      }

      assert {:error, changeset} = Families.add_swap(attrs)

      assert %{
               from: ["dia fora de escala"]
             } = errors_on(changeset)
    end

    test "error if swapping to the past" do
      today = Date.utc_today()
      yesterday = Date.add(today, -1)

      family =
        insert(:family,
          weekdays: [:monday, :tuesday, :wednesday, :thursday, :friday, :saturday, :sunday]
        )

      attrs = %{
        family_id: family.id,
        from: today,
        to: yesterday
      }

      assert {:error, changeset} = Families.add_swap(attrs)

      assert %{
               to: ["não é possível trocar para o passado"]
             } = errors_on(changeset)
    end

    test "error if invalid attrs" do
      %{id: family_id} = insert(:family)

      attrs = %{family_id: family_id}

      assert {:error, changeset} = Families.add_swap(attrs)

      assert errors_on(changeset) == %{
               to: ["obrigatório"],
               from: ["obrigatório"]
             }
    end
  end
end

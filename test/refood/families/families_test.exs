defmodule Refood.FamiliesTest do
  use Refood.DataCase, async: true

  alias Refood.Families

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

    # test "returns swapped families for the day" do
    # end
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
end

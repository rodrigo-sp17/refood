defmodule Refood.FamiliesTest do
  use Refood.DataCase, async: true

  alias Refood.Families

  describe "list_families_by_date/1" do
    setup do
      f1 = insert(:family, name: "Joao", weekdays: [:monday, :tuesday])
      f2 = insert(:family, name: "Maria", weekdays: [:thursday, :friday])
      f3 = insert(:family, name: "Abreu", weekdays: [:tuesday, :wednesday, :thursday])
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

    test "returns empty list if no families match" do
      assert [] == Families.list_families_by_date(~D[2024-06-15])
    end

    # test "returns shifted families for the day" do
    # end
  end
end

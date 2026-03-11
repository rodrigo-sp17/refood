defmodule Refood.Fridges.FridgesTest do
  use Refood.DataCase, async: true

  alias Refood.Fridges

  describe "fridges" do
    test "list_fridges/0 returns fridges ordered by name" do
      insert(:fridge, name: "FRIDGE B")
      insert(:fridge, name: "FRIDGE A")

      names = Fridges.list_fridges() |> Enum.map(& &1.name)
      assert names == ["FRIDGE A", "FRIDGE B"]
    end

    test "create_fridge/1 creates a fridge and uppercases the name" do
      assert {:ok, fridge} = Fridges.create_fridge(%{"name" => "fridge 1"})
      assert fridge.name == "FRIDGE 1"
    end

    test "create_fridge/1 returns error for duplicate name" do
      insert(:fridge, name: "FRIDGE 1")
      assert {:error, changeset} = Fridges.create_fridge(%{"name" => "fridge 1"})
      assert "has already been taken" in errors_on(changeset).name
    end

    test "delete_fridge/1 deletes the fridge and cascades its records" do
      fridge = insert(:fridge)
      insert(:temperature_record, fridge: fridge)

      assert {:ok, _} = Fridges.delete_fridge(fridge)
      assert Fridges.list_fridges() == []
      assert Fridges.list_temperature_records() == []
    end
  end

  describe "temperature records" do
    test "create_record/1 creates a temperature record" do
      fridge = insert(:fridge)

      assert {:ok, record} =
               Fridges.create_record(%{
                 "fridge_id" => fridge.id,
                 "temperature" => "4.5",
                 "recorded_at" => DateTime.utc_now()
               })

      assert Decimal.equal?(record.temperature, Decimal.new("4.5"))
    end

    test "upsert_record/3 creates on first call" do
      fridge = insert(:fridge)
      recorded_at = DateTime.utc_now() |> DateTime.truncate(:second)

      assert {:ok, record} = Fridges.upsert_record(fridge.id, recorded_at, "3.2")
      assert Decimal.equal?(record.temperature, Decimal.new("3.2"))
    end

    test "upsert_record/3 updates on second call for same fridge+datetime" do
      fridge = insert(:fridge)
      recorded_at = DateTime.utc_now() |> DateTime.truncate(:second)

      {:ok, _} = Fridges.upsert_record(fridge.id, recorded_at, "3.2")
      assert {:ok, record} = Fridges.upsert_record(fridge.id, recorded_at, "5.0")
      assert Decimal.equal?(record.temperature, Decimal.new("5.0"))
    end

    test "list_temperature_records/0 returns data grouped by datetime descending" do
      fridge = insert(:fridge)
      now = DateTime.utc_now() |> DateTime.truncate(:second)
      yesterday = DateTime.add(now, -86_400)

      insert(:temperature_record,
        fridge: fridge,
        recorded_at: now,
        temperature: Decimal.new("4.0")
      )

      insert(:temperature_record,
        fridge: fridge,
        recorded_at: yesterday,
        temperature: Decimal.new("5.0")
      )

      records = Fridges.list_temperature_records()

      assert length(records) == 2
      [{first_date, _}, {second_date, _}] = records
      assert Date.compare(first_date, second_date) == :gt
    end

    test "list_temperature_records/0 keys records by fridge_id" do
      fridge = insert(:fridge)
      insert(:temperature_record, fridge: fridge)

      [{_date, by_fridge}] = Fridges.list_temperature_records()
      assert Map.has_key?(by_fridge, fridge.id)
    end
  end
end

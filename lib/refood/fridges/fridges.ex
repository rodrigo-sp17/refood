defmodule Refood.Fridges do
  import Ecto.Query

  alias Refood.Fridges.Fridge
  alias Refood.Fridges.TemperatureRecord
  alias Refood.Repo

  # --- Fridges ---

  def list_fridges do
    Repo.all(from f in Fridge, order_by: f.name)
  end

  def get_fridge!(id), do: Repo.get!(Fridge, id)

  def create_fridge(attrs) do
    Fridge.changeset(attrs) |> Repo.insert()
  end

  def change_fridge(fridge \\ %Fridge{}) do
    Fridge.changeset(fridge, %{})
  end

  def delete_fridge(fridge) do
    Repo.delete(fridge)
  end

  # --- Temperature Records ---

  def list_temperature_records(opts \\ []) do
    limit = Keyword.get(opts, :limit, 60)

    from(r in TemperatureRecord,
      order_by: [desc: r.recorded_at],
      limit: ^limit
    )
    |> Repo.all()
    |> group_by_date_and_fridge()
  end

  defp group_by_date_and_fridge(records) do
    records
    |> Enum.group_by(fn r -> r.recorded_at end)
    |> Enum.sort_by(fn {recorded_at, _} -> recorded_at end, {:desc, NaiveDateTime})
    |> Enum.map(fn {recorded_at, recs} ->
      by_fridge =
        recs
        |> Enum.uniq_by(& &1.fridge_id)
        |> Map.new(fn r -> {r.fridge_id, r} end)

      {recorded_at, by_fridge}
    end)
  end

  def get_record_for_datetime(fridge_id, datetime) do
    from(r in TemperatureRecord,
      where: r.fridge_id == ^fridge_id and r.recorded_at == ^datetime,
      order_by: [desc: r.recorded_at],
      limit: 1
    )
    |> Repo.one()
  end

  def create_record(attrs) do
    TemperatureRecord.changeset(attrs) |> Repo.insert()
  end

  def update_record(record, attrs) do
    TemperatureRecord.changeset(record, attrs) |> Repo.update()
  end

  def upsert_record(fridge_id, recorded_at, temperature) do
    attrs = %{
      "fridge_id" => fridge_id,
      "recorded_at" => recorded_at,
      "temperature" => temperature
    }

    case get_record_for_datetime(fridge_id, recorded_at) do
      nil -> create_record(attrs)
      record -> update_record(record, attrs)
    end
  end
end

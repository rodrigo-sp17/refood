defmodule Refood.Repo.Migrations.CreateTemperatureRecords do
  use Ecto.Migration

  def change do
    create table(:temperature_records, primary_key: false) do
      add :id, :uuid, null: false, default: fragment("uuid_generate_v4()"), primary_key: true
      add :temperature, :decimal, null: false
      add :recorded_at, :utc_datetime, null: false
      add :fridge_id, references(:fridges, type: :uuid, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:temperature_records, [:fridge_id, :recorded_at])
    create index(:temperature_records, [:recorded_at])
  end
end

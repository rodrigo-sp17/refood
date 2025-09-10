defmodule Refood.Repo.Migrations.CreateAlerts do
  use Ecto.Migration

  def change do
    create table(:alerts, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :type, :string, null: false
      add :dismissed_at, :utc_datetime
      add :family_id, references(:families, type: :uuid, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:alerts, [:family_id, desc_nulls_first: :dismissed_at])
    create index(:alerts, [:type])

    create unique_index(:alerts, [:family_id, :type], where: "dismissed_at IS NULL")
  end
end

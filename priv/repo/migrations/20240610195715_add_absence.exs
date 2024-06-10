defmodule Refood.Repo.Migrations.AddAbsence do
  use Ecto.Migration

  def change do
    create table(:absences, primary_key: false) do
      add :id, :uuid, null: false, default: fragment("uuid_generate_v4()"), primary_key: true
      add :date, :date, null: false
      add :warned, :boolean, null: false

      add :family_id, references(:families, column: :id, type: :uuid, on_delete: :delete_all)

      timestamps(type: :utc_datetime)
    end

    create index(:absences, [:family_id, :warned])
    create index(:absences, [:date])
    create unique_index(:absences, [:family_id, :date])
  end
end

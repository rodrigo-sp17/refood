defmodule Refood.Repo.Migrations.CreateShiftCodes do
  use Ecto.Migration

  def change do
    create table(:shift_codes, primary_key: false) do
      add :id, :uuid, null: false, default: fragment("uuid_generate_v4()"), primary_key: true
      add :date, :date, null: false
      add :code, :string, null: false
      add :expires_at, :utc_datetime, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:shift_codes, [:date])
  end
end

defmodule Refood.Repo.Migrations.CreateShiftTickets do
  use Ecto.Migration

  def change do
    create table(:shift_tickets, primary_key: false) do
      add :id, :uuid, null: false, default: fragment("uuid_generate_v4()"), primary_key: true

      add :shift_code_id, references(:shift_codes, type: :uuid, on_delete: :delete_all),
        null: false

      add :family_id, references(:families, type: :uuid, on_delete: :delete_all), null: false
      add :position, :integer, null: false
      add :source, :string, null: false, default: "family"

      timestamps(type: :utc_datetime)
    end

    create unique_index(:shift_tickets, [:shift_code_id, :family_id])
    create unique_index(:shift_tickets, [:shift_code_id, :position])
  end
end

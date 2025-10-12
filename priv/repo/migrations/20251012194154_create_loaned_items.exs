defmodule Refood.Repo.Migrations.CreateLoanedItems do
  use Ecto.Migration

  def change do
    create table(:loaned_items, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :family_id, references(:families, on_delete: :delete_all, type: :binary_id), null: false

      add :name, :string, null: false
      add :quantity, :integer, null: false, default: 1
      add :loaned_at, :utc_datetime, null: false
      add :returned_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:loaned_items, [:family_id])
    create index(:loaned_items, [:returned_at])
  end
end

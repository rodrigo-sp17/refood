defmodule Refood.Repo.Migrations.CreateSwaps do
  use Ecto.Migration

  def change do
    create table(:swaps, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :to, :date, null: false
      add :from, :date, null: false
      add :family_id, references(:families, on_delete: :delete_all, type: :uuid), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:swaps, [:family_id])
    create unique_index(:swaps, [:to, :family_id])
    create unique_index(:swaps, [:from, :family_id])
  end
end

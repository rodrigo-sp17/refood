defmodule Refood.Repo.Migrations.CreateFridges do
  use Ecto.Migration

  def change do
    create table(:fridges, primary_key: false) do
      add :id, :uuid, null: false, default: fragment("uuid_generate_v4()"), primary_key: true
      add :name, :string, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:fridges, [:name])
  end
end

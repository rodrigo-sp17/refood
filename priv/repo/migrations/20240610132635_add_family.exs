defmodule Refood.Repo.Migrations.AddFamily do
  use Ecto.Migration

  def change do
    create table(:families, primary_key: false) do
      add :id, :uuid, null: false, default: fragment("uuid_generate_v4()"), primary_key: true
      add :number, :integer, null: false
      add :name, :string, null: false
      add :adults, :integer, null: false
      add :children, :integer, null: false
      add :restrictions, :text
      add :weekdays, {:array, :string}, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:families, [:number])
    create index(:families, [:weekdays])
  end
end

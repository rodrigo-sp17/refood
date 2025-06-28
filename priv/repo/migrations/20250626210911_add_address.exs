defmodule Refood.Repo.Migrations.AddAddress do
  use Ecto.Migration

  def change do
    create table(:addresses, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :line_1, :string
      add :line_2, :string
      add :region, :string
      add :city, :string
      add :zipcode, :string

      add :family_id, references(:families, on_delete: :delete_all, type: :uuid), null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:addresses, [:family_id])
  end
end

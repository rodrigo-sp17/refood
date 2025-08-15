defmodule Refood.Repo.Migrations.AddNewFieldsToFamily do
  use Ecto.Migration

  def change do
    alter table(:families) do
      add :speaks_portuguese, :boolean, null: false, default: true
      add :help_requested_at, :utc_datetime
      add :cc, :string
      add :nif, :string
      add :niss, :string
      add :last_contacted_at, :utc_datetime
    end
  end
end

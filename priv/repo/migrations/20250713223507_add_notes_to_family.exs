defmodule Refood.Repo.Migrations.AddNotesToFamily do
  use Ecto.Migration

  def change do
    alter table(:families) do
      add :notes, :text
    end
  end
end

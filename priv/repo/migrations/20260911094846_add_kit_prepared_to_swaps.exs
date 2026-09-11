defmodule Refood.Repo.Migrations.AddKitPreparedToSwaps do
  use Ecto.Migration

  def change do
    alter table(:swaps) do
      add :kit_prepared, :boolean, null: false, default: false
    end
  end
end

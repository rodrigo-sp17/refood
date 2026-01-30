defmodule Refood.Repo.Migrations.RemoveQueuePositionUseTimestampOrdering do
  use Ecto.Migration

  def change do
    alter table(:families) do
      remove :queue_position
    end

    drop_if_exists index(:families, [:queue_position])
  end
end

defmodule Refood.Repo.Migrations.AddQueueToFamily do
  use Ecto.Migration

  def change do
    alter table(:families) do
      add :status, :string
      add :queue_position, :integer

      add :phone_number, :string
      add :email, :string

      modify :number, :integer, null: true
      modify :weekdays, {:array, :string}, null: true
    end

    create index(:families, [:status])
    create index(:families, [:queue_position])
  end
end

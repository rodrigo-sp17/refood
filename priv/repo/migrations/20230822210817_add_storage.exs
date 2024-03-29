defmodule Refood.Repo.Migrations.AddStorage do
  @moduledoc """
  Updates resources based on their most recent snapshots.

  This file was autogenerated with `mix ash_postgres.generate_migrations`
  """

  use Ecto.Migration

  def up do
    create table(:storages, primary_key: false) do
      add :id, :uuid, null: false, default: fragment("uuid_generate_v4()"), primary_key: true
      add :name, :text, null: false

      add :inserted_at, :utc_datetime_usec, null: false, default: fragment("now()")
      add :updated_at, :utc_datetime_usec, null: false, default: fragment("now()")
    end

    create table(:storage_items, primary_key: false) do
      add :id, :uuid, null: false, default: fragment("uuid_generate_v4()"), primary_key: true
      add :expires_at, :date

      add :product_id,
          references(:products,
            column: :id,
            name: "storage_items_product_id_fkey",
            type: :uuid,
            prefix: "public"
          ),
          null: false

      add :storage_id,
          references(:storages,
            column: :id,
            name: "storage_items_storage_id_fkey",
            type: :uuid,
            prefix: "public"
          )

      add :inserted_at, :utc_datetime_usec, null: false, default: fragment("now()")
      add :updated_at, :utc_datetime_usec, null: false, default: fragment("now()")
    end
  end

  def down do
    drop constraint(:storage_items, "storage_items_product_id_fkey")

    drop constraint(:storage_items, "storage_items_storage_id_fkey")

    drop table(:storage_items)

    drop table(:storages)
  end
end

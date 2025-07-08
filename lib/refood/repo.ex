defmodule Refood.Repo do
  use Ecto.Repo,
    otp_app: :refood,
    adapter: Ecto.Adapters.Postgres

  # Installs Postgres extensions that ash commonly uses
  def installed_extensions do
    ["uuid-ossp", "citext"]
  end
end

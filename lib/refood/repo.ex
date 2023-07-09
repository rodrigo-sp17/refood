defmodule Refood.Repo do
  use Ecto.Repo,
    otp_app: :refood,
    adapter: Ecto.Adapters.Postgres
end

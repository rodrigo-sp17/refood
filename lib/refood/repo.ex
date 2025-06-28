defmodule Refood.Repo do
  use Ecto.Repo,
    otp_app: :refood,
    adapter: Ecto.Adapters.Postgres

  def transact(fun_or_multi, opts \\ []) do
    {_tx_res, res} =
      transaction(
        fn ->
          with {:error, _} = error <- fun_or_multi.() do
            rollback(error)
          end
        end,
        opts
      )

    res
  end

  # Installs Postgres extensions that ash commonly uses
  def installed_extensions do
    ["uuid-ossp", "citext"]
  end
end

defmodule RefoodWeb.Plugs.Authorize do
  import Plug.Conn

  def init(roles) when is_list(roles), do: roles

  def call(conn, roles) do
    if conn.assigns[:current_user] && conn.assigns.current_user.role in roles do
      conn
    else
      conn
      |> put_status(:forbidden)
      |> Phoenix.Controller.text("Acesso negado")
      |> halt()
    end
  end
end

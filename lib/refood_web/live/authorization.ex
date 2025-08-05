defmodule RefoodWeb.Authorization do
  @moduledoc """
  Authorizes a specific user role to a socket action.
  """

  alias Refood.Accounts.User

  def authorize(socket, roles) do
    with %{assigns: %{current_user: %User{} = user}} <- socket,
         true <- user.role in roles do
      {:ok, socket}
    else
      _ ->
        socket = Phoenix.LiveView.put_flash(socket, :error, "Proibido")
        {:noreply, socket}
    end
  end
end

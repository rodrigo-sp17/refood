defmodule RefoodWeb.UserForgotPasswordLive do
  use RefoodWeb, :live_view

  alias Refood.Accounts

  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-sm">
      <.header class="text-center">
        Esqueceu sua palavra-passe?
        <:subtitle>Enviaremos um link de reset para sua inbox</:subtitle>
      </.header>


      <.simple_form  for={@form} id="reset_password_form" phx-submit="send_email">
        <.input field={@form[:email]} type="email" placeholder="Email" required />
        <:actions>
          <.button phx-disable-with="Sending..." class="w-full">
            Enviar instruções de reset de palavra-passe
          </.button>
        </:actions>
      </.simple_form>

      <p class="text-center text-sm mt-4">
         <.link href={~p"/users/log_in"}> Log in</.link>
      </p>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    {:ok, assign(socket, form: to_form(%{}, as: "user"))}
  end

  def handle_event("send_email", %{"user" => %{"email" => email}}, socket) do
    if user = Accounts.get_user_by_email(email) do
      Accounts.deliver_user_reset_password_instructions(
        user,
        &url(~p"/users/reset_password/#{&1}")
      )
    end

    info =
      "Se o email está em nosso sistema, receberá brevemente instruções para resetar a palavra-passe."

    {:noreply,
     socket
     |> put_flash(:info, info)
     |> redirect(to: ~p"/users/log_in")}
  end
end

defmodule RefoodWeb.UserForgotPasswordLive do
  use RefoodWeb, :live_view

  alias Refood.Accounts

  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-sm">
      <.header class="text-center">
        Esqueceu a palavra-passe?
        <:subtitle>Enviamos um link para definir uma nova.</:subtitle>
      </.header>

      <.form
        for={@form}
        id="reset_password_form"
        phx-submit="send_email"
        class="mt-8 flex flex-col gap-5"
      >
        <.input field={@form[:email]} type="email" label="Email" required />
        <.button phx-disable-with="A enviar..." full_width size={:lg}>
          Enviar instruções
        </.button>
      </.form>

      <p class="mt-6 text-center text-sm">
        <.link href={~p"/users/log_in"} class="underline">Voltar ao início de sessão</.link>
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

defmodule RefoodWeb.UserConfirmationInstructionsLive do
  use RefoodWeb, :live_view

  alias Refood.Accounts

  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-sm">
      <.header class="text-center">
        Não recebeu as instruções de confirmação?
        <:subtitle>Enviamos um novo link de confirmação para o seu email</:subtitle>
      </.header>

      <.form
        for={@form}
        id="resend_confirmation_form"
        phx-submit="send_instructions"
        class="mt-8 flex flex-col gap-5"
      >
        <.input field={@form[:email]} type="email" label="Email" required />
        <.button phx-disable-with="A enviar..." full_width size={:lg}>
          Enviar novo link
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

  def handle_event("send_instructions", %{"user" => %{"email" => email}}, socket) do
    if user = Accounts.get_user_by_email(email) do
      Accounts.deliver_user_confirmation_instructions(
        user,
        &url(~p"/users/confirm/#{&1}")
      )
    end

    info =
      "Se o email estiver no sistema e ainda não tiver sido confirmado, receberá as instruções em breve."

    {:noreply,
     socket
     |> put_flash(:info, info)
     |> redirect(to: ~p"/users/log_in")}
  end
end

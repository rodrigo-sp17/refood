defmodule RefoodWeb.UserResetPasswordLive do
  use RefoodWeb, :live_view

  alias Refood.Accounts

  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-sm">
      <.header class="text-center">Resetar palavra-passe</.header>

      <.form
        for={@form}
        id="reset_password_form"
        phx-submit="reset_password"
        phx-change="validate"
        class="mt-8 flex flex-col gap-5"
      >
        <.error_summary form={@form} />

        <.input field={@form[:password]} type="password" label="Nova palavra-passe" />
        <.input
          field={@form[:password_confirmation]}
          type="password"
          label="Confirme a nova palavra-passe"
        />
        <.button phx-disable-with="A guardar..." full_width size={:lg}>
          Definir palavra-passe
        </.button>
      </.form>

      <p class="mt-6 text-center text-sm">
        <.link href={~p"/users/log_in"} class="underline">Voltar ao início de sessão</.link>
      </p>
    </div>
    """
  end

  def mount(params, _session, socket) do
    socket = assign_user_and_token(socket, params)

    form_source =
      case socket.assigns do
        %{user: user} ->
          Accounts.change_user_password(user)

        _ ->
          %{}
      end

    {:ok, assign_form(socket, form_source), temporary_assigns: [form: nil]}
  end

  # Do not log in the user after reset password to avoid a
  # leaked token giving the user access to the account.
  def handle_event("reset_password", %{"user" => user_params}, socket) do
    case Accounts.reset_user_password(socket.assigns.user, user_params) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Palavra-passe resetada.")
         |> redirect(to: ~p"/users/log_in")}

      {:error, changeset} ->
        {:noreply, assign_form(socket, Map.put(changeset, :action, :insert))}
    end
  end

  def handle_event("validate", %{"user" => user_params}, socket) do
    changeset = Accounts.change_user_password(socket.assigns.user, user_params)
    {:noreply, assign_form(socket, Map.put(changeset, :action, :validate))}
  end

  defp assign_user_and_token(socket, %{"token" => token}) do
    if user = Accounts.get_user_by_reset_password_token(token) do
      assign(socket, user: user, token: token)
    else
      socket
      |> put_flash(:error, "Link de reset inválido ou expirado.")
      |> redirect(to: ~p"/users/log_in")
    end
  end

  defp assign_form(socket, %{} = source) do
    assign(socket, :form, to_form(source, as: "user"))
  end
end

defmodule RefoodWeb.UserLoginLive do
  use RefoodWeb, :live_view

  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-md bg-white p-10">
      <div class="flex justify-center gap-3">
        <img src={~p"/images/refood-cropped-192.png"} width="28" class="" />
        <.header class="text-center flex flex-row justify-center">
          REFOOD - Login
        </.header>
      </div>
      <.form
        for={@form}
        id="login_form"
        action={~p"/users/log_in"}
        phx-update="ignore"
        class="mt-8 flex flex-col gap-5"
      >
        <.input field={@form[:email]} type="email" label="Email" required />
        <.input field={@form[:password]} type="password" label="Palavra-passe" required />

        <div class="flex items-center justify-between gap-4">
          <.input field={@form[:remember_me]} type="checkbox" label="Manter sessão iniciada" />
          <.link href={~p"/users/reset_password"} class="text-sm font-semibold underline">
            Esqueceu a palavra-passe?
          </.link>
        </div>
        <.button phx-disable-with="A entrar..." full_width size={:lg}>Entrar</.button>
      </.form>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    email = Phoenix.Flash.get(socket.assigns.flash, :email)
    form = to_form(%{"email" => email}, as: "user")
    {:ok, assign(socket, form: form), temporary_assigns: [form: form]}
  end
end

defmodule RefoodWeb.UsersLive.NewUser do
  @moduledoc """
  Adds a new user.
  """

  use RefoodWeb, :live_component

  alias Refood.Accounts
  alias Refood.Accounts.User

  @impl true
  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> assign(changeset: Accounts.change_user_registration(%User{}))

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.modal show id={@id} on_cancel={@on_cancel}>
        <.header>Criar novo usuário</.header>
        <.simple_form
          :let={f}
          id="registration-form"
          for={@changeset}
          phx-target={@myself}
          phx-submit="create-user"
        >
          <.input field={f[:name]} type="text" label="Nome" required />
          <.input field={f[:email]} type="email" label="Email" required />
          <.input
            field={f[:role]}
            type="select"
            options={["manager", "shift"]}
            label="Função"
            required
          />
          <.input field={f[:password]} type="password" label="Palavra-passe" required />
          <.error :if={@changeset.action}>
            Oops, algo de errado aconteceu!
          </.error>

          <:actions>
            <.button phx-disable-with="Criando usuário..." class="w-full">Criar usuário</.button>
          </:actions>
        </.simple_form>
      </.modal>
    </div>
    """
  end

  @impl true
  def handle_event("create-user", %{"user" => user_attrs}, socket) do
    case Accounts.register_user(socket.assigns.current_user, user_attrs) do
      {:ok, created_user} ->
        send(self(), {:user_created, created_user})
        send(self(), {:put_flash, [:info, "Usuário criado!"]})

        {:noreply, socket}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, changeset: changeset)}
    end
  end
end

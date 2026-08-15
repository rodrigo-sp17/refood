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
      |> assign(form: to_form(Accounts.change_user_registration(%User{})))

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.modal show id={@id} on_cancel={@on_cancel} size={:md}>
        <:header>Criar novo usuário</:header>
        <:footer>
          <div class="flex justify-end gap-3">
            <.button type="button" variant={:ghost} phx-click={@on_cancel}>Cancelar</.button>
            <.button type="submit" form="registration-form" phx-disable-with="A criar...">
              Criar usuário
            </.button>
          </div>
        </:footer>
        <.record_form
          :let={rf}
          id="registration-form"
          for={@form}
          phx-target={@myself}
          phx-change="validate"
          phx-submit="create-user"
        >
          <.section title="Utilizador">
            <.field rf={rf} name={:name} label="Nome" width={:md} required />
            <.field rf={rf} name={:email} label="Email" type="email" width={:md} required />
            <.field
              rf={rf}
              name={:role}
              label="Função"
              type="select"
              width={:sm}
              options={role_options()}
              required
            />
            <.field
              rf={rf}
              name={:password}
              label="Palavra-passe"
              type="password"
              width={:md}
              required
            />
          </.section>
        </.record_form>
      </.modal>
    </div>
    """
  end

  defp role_options, do: [{"Gestor", "manager"}, {"Turno", "shift"}]

  @impl true
  def handle_event("validate", %{"user" => user_attrs}, socket) do
    form =
      %User{}
      |> Accounts.change_user_registration(user_attrs)
      |> to_form(action: :validate)

    {:noreply, assign(socket, form: form)}
  end

  @impl true
  def handle_event("create-user", %{"user" => user_attrs}, socket) do
    case Accounts.register_user(socket.assigns.current_user, user_attrs) do
      {:ok, created_user} ->
        send(self(), {:user_created, created_user})
        send(self(), {:put_flash, [:info, "Usuário criado!"]})

        {:noreply, socket}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end
end

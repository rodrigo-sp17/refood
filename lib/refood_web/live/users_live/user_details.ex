defmodule RefoodWeb.UsersLive.UserDetails do
  use RefoodWeb, :live_component

  alias Refood.Accounts

  @impl true
  def update(%{user: user} = assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> assign(changeset: Accounts.change_update_user_details(user), edit: false)

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.modal show id={@id} on_cancel={@on_cancel} edit={@edit} target={@myself}>
        <:header>
          Usuário {@user.name}
        </:header>
        <.simple_form
          :let={f}
          id="update-user-details-form"
          for={@changeset}
          phx-target={@myself}
          phx-submit="update-user"
        >
          <.input edit={@edit} field={f[:name]} type="text" label="Nome" required />
          <.input edit={false} field={f[:email]} type="email" label="Email" />
          <.input
            edit={@edit}
            field={f[:role]}
            type="select"
            options={["manager", "shift"]}
            label="Função"
            required
          />
          <.error :if={@changeset.action}>
            Oops, algo de errado aconteceu!
          </.error>

          <:actions>
            <.button :if={@edit} phx-disable-with="Editando usuário..." class="w-full">
              Editar usuário
            </.button>
          </:actions>
        </.simple_form>
      </.modal>
    </div>
    """
  end

  @impl true
  def handle_event("edit", _, socket) do
    {:noreply, assign(socket, edit: true)}
  end

  @impl true
  def handle_event("update-user", %{"user" => user_attrs}, socket) do
    case Accounts.update_user(socket.assigns.current_user, socket.assigns.user, user_attrs) do
      {:ok, updated_user} ->
        send(self(), {:user_updated, updated_user})
        send(self(), {:put_flash, [:info, "Usuário editado!"]})

        {:noreply, socket}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, changeset: changeset)}
    end
  end
end

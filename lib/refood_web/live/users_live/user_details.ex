defmodule RefoodWeb.UsersLive.UserDetails do
  use RefoodWeb, :live_component

  alias Refood.Accounts

  @impl true
  def update(%{user: user} = assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> assign(:mode, :read)
      |> assign(:form, to_form(Accounts.change_update_user_details(user)))

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.modal show id={@id} on_cancel={@on_cancel} edit={@mode == :edit} target={@myself} size={:md}>
        <:header>{@user.name}</:header>
        <:subtitle>{@user.email}</:subtitle>

        <:footer :if={@mode == :edit}>
          <.form_actions
            form={@form}
            submit_form="update-user-details-form"
            target={@myself}
            submit_label="Guardar utilizador"
          />
        </:footer>

        <.record_form
          :let={rf}
          id="update-user-details-form"
          for={@form}
          mode={@mode}
          phx-target={@myself}
          phx-change="validate"
          phx-submit="update-user"
        >
          <.section title="Utilizador">
            <.field rf={rf} name={:name} label="Nome" width={:md} required />
            <.field
              rf={rf}
              name={:email}
              label="Email"
              type="email"
              width={:md}
              readonly
              hint="O email não pode ser alterado aqui."
            />
            <.field
              rf={rf}
              name={:role}
              label="Função"
              type="select"
              width={:sm}
              options={role_options()}
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
  def handle_event("edit", _, socket) do
    {:noreply, assign(socket, mode: :edit)}
  end

  @impl true
  def handle_event("cancel-edit", _, socket) do
    form = to_form(Accounts.change_update_user_details(socket.assigns.user))
    {:noreply, assign(socket, mode: :read, form: form)}
  end

  @impl true
  def handle_event("validate", %{"user" => user_attrs}, socket) do
    form =
      socket.assigns.user
      |> Accounts.change_update_user_details(user_attrs)
      |> to_form(action: :validate)

    {:noreply, assign(socket, form: form)}
  end

  @impl true
  def handle_event("update-user", %{"user" => user_attrs}, socket) do
    case Accounts.update_user(socket.assigns.current_user, socket.assigns.user, user_attrs) do
      {:ok, updated_user} ->
        send(self(), {:user_updated, updated_user})
        send(self(), {:put_flash, [:info, "Usuário guardado!"]})

        {:noreply, socket}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end
end

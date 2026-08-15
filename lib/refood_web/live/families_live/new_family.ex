defmodule RefoodWeb.FamiliesLive.NewFamily do
  @moduledoc """
  Form to create a new family.
  """
  use RefoodWeb, :live_component

  alias Refood.Families

  @impl true
  def update(assigns, socket) do
    updated_assigns =
      Map.merge(assigns, %{
        form: to_form(Families.change_create_family(Families.new_family_attrs()))
      })

    {:ok, assign(socket, updated_assigns)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.modal show id={@id} on_cancel={@on_cancel}>
        <:header>Criar nova família</:header>
        <:subtitle>Uma família nova entra como inativa até ser colocada em ajuda regular.</:subtitle>
        <:footer>
          <div class="flex justify-end gap-3">
            <.button type="button" variant={:ghost} phx-click={@on_cancel}>Cancelar</.button>
            <.button type="submit" form="new-family-form">Criar família</.button>
          </div>
        </:footer>
        <.record_form
          :let={rf}
          id="new-family-form"
          for={@form}
          phx-change="validate"
          phx-target={@myself}
          phx-submit="create-family"
        >
          <.section title="Identificação">
            <.field rf={rf} name={:name} label="Nome" required />
            <.field rf={rf} name={:adults} label="Adultos" type="number" width={:xs} min="1" step="1" />
            <.field
              rf={rf}
              name={:children}
              label="Crianças"
              type="number"
              width={:xs}
              min="0"
              step="1"
            />
            <.field rf={rf} name={:email} label="Email" type="email" width={:md} />
            <.field rf={rf} name={:phone_number} label="Telefone" type="tel" width={:sm} />
            <.field rf={rf} name={:speaks_portuguese} label="Fala português" type="checkbox" />
            <.field rf={rf} name={:cc} label="CC" width={:sm} />
            <.field rf={rf} name={:nif} label="NIF" width={:sm} />
            <.field rf={rf} name={:niss} label="NISS" width={:sm} />
          </.section>

          <.section title="Morada">
            <.inputs_for :let={fa} id="address-block" field={rf.form[:address]}>
              <.field rf={rf} form={fa} name={:line_1} label="Endereço" />
              <.field rf={rf} form={fa} name={:line_2} label="Complemento" />
              <.field rf={rf} form={fa} name={:region} label="Região" width={:md} required />
              <.field rf={rf} form={fa} name={:city} label="Cidade" width={:md} required />
            </.inputs_for>
          </.section>

          <.section title="Agregado">
            <.field
              rf={rf}
              name={:restrictions}
              label="Restrições"
              type="textarea"
              hint="Alimentos que esta família não pode receber."
            />
            <.field rf={rf} name={:notes} label="Notas" type="textarea" />
          </.section>

          <.section title="Acompanhamento">
            <.field
              rf={rf}
              name={:help_requested_at}
              label="Ajuda pedida em"
              type="datetime-local"
              width={:sm}
            />
            <.field
              rf={rf}
              name={:last_contacted_at}
              label="Último contacto"
              type="datetime-local"
              width={:sm}
            />
          </.section>
        </.record_form>
      </.modal>
    </div>
    """
  end

  @impl true
  def handle_event("validate", %{"family" => family_attrs}, socket) do
    form =
      to_form(Families.change_create_family(family_attrs), action: :validate)

    {:noreply, assign(socket, form: form)}
  end

  @impl true
  def handle_event("create-family", %{"family" => family_attrs}, socket) do
    case Families.create_family(family_attrs) do
      {:ok, created_request} ->
        socket.assigns.on_created.(created_request)

        {:noreply, put_flash(socket, :info, "Família criada!")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end
end

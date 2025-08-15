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
        form: to_form(Families.change_create_family(%{}))
      })

    {:ok, assign(socket, updated_assigns)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.modal show id={@id} on_cancel={@on_cancel}>
        <:header>Criar nova família</:header>
        <.simple_form
          id="new-family-form"
          for={@form}
          phx-change="validate"
          phx-target={@myself}
          phx-submit="create-family"
        >
          <.form_section>Informações gerais</.form_section>
          <div class="flex gap-4 justify-stretch">
            <div class="flex-3/5">
              <.input field={@form[:name]} type="text" label="Nome" />
            </div>
            <div class="flex-1/5">
              <.input
                field={@form[:adults]}
                type="number"
                min="0"
                step="1"
                pattern="[0-9]*"
                label="Adultos"
                value={1}
              />
            </div>
            <div class="flex-1/5">
              <.input
                field={@form[:children]}
                type="number"
                min="0"
                step="1"
                pattern="[0-9]*"
                label="Crianças"
                value={0}
              />
            </div>
          </div>

          <div class="flex gap-4 justify-stretch">
            <div class="flex-3/5"><.input field={@form[:email]} type="email" label="Email" /></div>
            <div class="flex-2/5">
              <.input field={@form[:phone_number]} type="tel" label="Telefone" />
            </div>
          </div>
          <.form_section class="pt-10">Morada</.form_section>
          <.inputs_for :let={fa} id="address-block" field={@form[:address]}>
            <.input field={fa[:line_1]} type="text" label="Endereço" />
            <.input field={fa[:line_2]} type="text" label="Complemento" />
            <div class="flex gap-4 justify-stretch">
              <div class="w-full">
                <.input field={fa[:region]} type="text" label="Região" />
              </div>
              <div class="w-full">
                <.input field={fa[:city]} type="text" label="Cidade" value="Porto" />
              </div>
            </div>
          </.inputs_for>
          <.form_section class="pt-10">Agregado</.form_section>

          <.input field={@form[:restrictions]} type="textarea" label="Restrições" />
          <.input field={@form[:notes]} type="textarea" label="Notas" />
          <:actions>
            <.button class="w-full">Salvar</.button>
          </:actions>
        </.simple_form>
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

        {:noreply,
         socket
         |> put_flash(:info, "Sucesso!")
         |> assign(edit: false)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end
end

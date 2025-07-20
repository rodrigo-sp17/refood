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
        changeset: Families.change_create_family(%{})
      })

    {:ok, assign(socket, updated_assigns)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.modal show id={@id} on_cancel={@on_cancel}>
        <.header>Criar nova família</.header>
        <.simple_form :let={f} for={@changeset} phx-target={@myself} phx-submit="create-family">
          <.input field={f[:name]} type="text" label="Nome" />
          <div class="flex gap-4 justify-stretch">
            <div class="w-full">
              <.input
                field={f[:adults]}
                type="number"
                min="0"
                step="1"
                pattern="[0-9]*"
                label="Adultos"
                value={1}
              />
            </div>
            <div class="w-full">
              <.input
                field={f[:children]}
                type="number"
                min="0"
                step="1"
                pattern="[0-9]*"
                label="Crianças"
                value={0}
              />
            </div>
          </div>
          <.input field={f[:phone_number]} type="tel" label="Telefone" />
          <.input field={f[:email]} type="email" label="Email" />
          <.inputs_for :let={fa} field={f[:address]}>
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
          <.input field={f[:restrictions]} type="textarea" label="Restrições" />
          <.input field={f[:notes]} type="textarea" label="Notas" />
          <.error :if={@changeset.action}>
            Oops, algo de errado aconteceu!
          </.error>

          <:actions>
            <.button class="w-full">Salvar</.button>
          </:actions>
        </.simple_form>
      </.modal>
    </div>
    """
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
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end
end

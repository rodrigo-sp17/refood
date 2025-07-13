defmodule RefoodWeb.HelpQueueLive.HelpRequestDetails do
  @moduledoc """
  Shows/edits a help request.
  """

  use RefoodWeb, :live_component

  alias Refood.Families

  @impl true
  def update(%{family: family} = assigns, socket) do
    updated_assigns =
      Map.merge(assigns, %{
        changeset: Families.change_update_help_request(family, %{}),
        edit: false
      })

    {:ok, assign(socket, updated_assigns)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.modal show id={@id} on_cancel={@on_cancel}>
        <.header>
          Pedido de ajuda para {@family.name}
          <:actions>
            <.button :if={!@edit} phx-target={@myself} phx-click="edit-help-request">Editar</.button>
          </:actions>
        </.header>

        <.simple_form :let={f} for={@changeset} phx-target={@myself} phx-submit="update-help-request">
          <.input disabled={!@edit} field={f[:name]} type="text" label="Nome" />
          <div class="flex gap-4 justify-stretch">
            <div class="w-full">
              <.input
                disabled={!@edit}
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
                disabled={!@edit}
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
          <.input disabled={!@edit} field={f[:phone_number]} type="tel" label="Telefone" />
          <.input disabled={!@edit} field={f[:email]} type="email" label="Email" />
          <.inputs_for :let={fa} field={f[:address]}>
            <.input disabled={!@edit} field={fa[:line_1]} type="text" label="Endereço" />
            <.input disabled={!@edit} field={fa[:line_2]} type="text" label="Complemento" />
            <div class="flex gap-4 justify-stretch">
              <div class="w-full">
                <.input disabled={!@edit} field={fa[:region]} type="text" label="Região" />
              </div>
              <div class="w-full">
                <.input disabled={!@edit} field={fa[:city]} type="text" label="Cidade" value="Porto" />
              </div>
            </div>
          </.inputs_for>
          <.input disabled={!@edit} field={f[:restrictions]} type="textarea" label="Restrições" />
          <.input disabled={!@edit} field={f[:notes]} type="textarea" label="Notas" />
          <.error :if={@changeset.action}>
            Oops, algo de errado aconteceu!
          </.error>

          <:actions>
            <.button :if={@edit} class="w-full">Salvar</.button>
          </:actions>
        </.simple_form>
      </.modal>
    </div>
    """
  end

  @impl true
  def handle_event("edit-help-request", _, socket) do
    {:noreply, assign(socket, edit: true)}
  end

  @impl true
  def handle_event("update-help-request", %{"family" => family_attrs}, socket) do
    case Families.update_help_request(socket.assigns.family, family_attrs) do
      {:ok, created_request} ->
        socket.assigns.on_created.(created_request)
        {:noreply, put_flash(socket, :info, "Sucesso!")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end
end

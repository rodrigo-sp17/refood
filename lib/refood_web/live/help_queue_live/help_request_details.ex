defmodule RefoodWeb.HelpQueueLive.HelpRequestDetails do
  @moduledoc """
  Shows/edits a help request.
  """
  use RefoodWeb, :live_component

  alias Refood.Families.HelpQueue

  @impl true
  def update(%{family: family} = assigns, socket) do
    updated_assigns =
      Map.merge(assigns, %{
        form: to_form(HelpQueue.change_update_help_request(family, %{})),
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

        <.simple_form id="help-request-details-form" for={@form} phx-change="validate" phx-target={@myself} phx-submit="update-help-request">
          <.input disabled={!@edit} field={@form[:name]} type="text" label="Nome" />
          <div class="flex gap-4 justify-stretch">
            <div class="w-full">
              <.input
                disabled={!@edit}
                field={@form[:adults]}
                type="number"
                min="0"
                step="1"
                pattern="[0-9]*"
                label="Adultos"
              />
            </div>
            <div class="w-full">
              <.input
                disabled={!@edit}
                field={@form[:children]}
                type="number"
                min="0"
                step="1"
                pattern="[0-9]*"
                label="Crianças"
              />
            </div>
          </div>
          <.input disabled={!@edit} field={@form[:phone_number]} type="tel" label="Telefone" />
          <.input disabled={!@edit} field={@form[:email]} type="email" label="Email" />
          <.inputs_for :let={fa} field={@form[:address]}>
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
          <.input disabled={!@edit} field={@form[:restrictions]} type="textarea" label="Restrições" />
          <.input disabled={!@edit} field={@form[:notes]} type="textarea" label="Notas" />
          <:actions>
            <.button :if={@edit} class="w-full">Salvar</.button>
          </:actions>
        </.simple_form>
      </.modal>
    </div>
    """
  end

  @impl true
  def handle_event("validate", %{"family" => attrs}, socket) do
    assigns = [
      edit: true,
      form: to_form(HelpQueue.change_update_help_request(socket.assigns.family, attrs))
    ]

    {:noreply, assign(socket, assigns)}
  end

  @impl true
  def handle_event("edit-help-request", _, socket) do
    assigns = [
      edit: true,
      form: to_form(HelpQueue.change_update_help_request(socket.assigns.family, %{}))
    ]

    {:noreply, assign(socket, assigns)}
  end

  @impl true
  def handle_event("update-help-request", %{"family" => family_attrs}, socket) do
    case HelpQueue.update_help_request(socket.assigns.family, family_attrs) do
      {:ok, created_request} ->
        socket.assigns.on_created.(created_request)
        {:noreply, put_flash(socket, :info, "Sucesso!")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  def handle_info({:updated_family, _}, socket) do
    assigns = [
      edit: false,
      form: to_form(HelpQueue.change_update_help_request(socket.assigns.family, %{}))
    ]

    {:noreply, assign(socket, assigns)}
  end
end

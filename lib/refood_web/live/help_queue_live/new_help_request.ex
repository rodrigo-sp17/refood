defmodule RefoodWeb.HelpQueueLive.NewHelpRequest do
  @moduledoc """
  Component that adds a new help request to the families list.
  """
  use RefoodWeb, :live_component

  alias Refood.Families

  @impl true
  def mount(socket) do
    assigns = [
      changeset: Families.change_request_help(%{})
    ]

    {:ok, assign(socket, assigns)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.modal show id={@id} on_cancel={@on_cancel}>
        <.header>
          Criar pedido de ajuda
        </.header>

        <.simple_form :let={f} for={@changeset} phx-target={@myself} phx-submit="add-help-request">
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
          <div class="flex gap-4 justify-stretch">
            <.inputs_for :let={fa} field={f[:address]}>
              <div class="w-full">
                <.input field={fa[:region]} type="text" label="Região" />
              </div>
              <div class="w-full">
                <.input field={fa[:city]} type="text" label="Cidade" value="Porto" />
              </div>
            </.inputs_for>
          </div>
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
  def handle_event("add-help-request", %{"family" => help_request_attrs}, socket) do
    case Families.request_help(help_request_attrs) do
      {:ok, created_request} ->
        socket.assigns.on_created.(created_request)
        {:noreply, put_flash(socket, :info, "Pedido de ajuda registrado!")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end
end

defmodule RefoodWeb.HelpQueueLive.NewHelpRequest do
  @moduledoc """
  Component that adds a new help request to the families list.
  """
  use RefoodWeb, :live_component

  alias Refood.Families.HelpQueue

  @impl true
  def mount(socket) do
    assigns = [
      form: to_form(HelpQueue.change_request_help(%{}))
    ]

    {:ok, assign(socket, assigns)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.modal show id={@id} on_cancel={@on_cancel}>
        <:header>
          Criar pedido de ajuda
        </:header>

        <.simple_form
          id="new-help-request-form"
          for={@form}
          phx-target={@myself}
          phx-change="validate"
          phx-submit="add-help-request"
        >
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
              />
            </div>
          </div>
          <div class="flex gap-4 justify-stretch">
            <div class="flex-3/5">
              <.input field={@form[:email]} type="email" label="Email" />
            </div>
            <div class="flex-2/5">
              <.input field={@form[:phone_number]} type="tel" label="Telefone" />
            </div>
          </div>
          <div class="flex gap-4 justify-stretch">
            <.inputs_for :let={fa} field={@form[:address]}>
              <div class="w-full">
                <.input field={fa[:region]} type="text" label="Região" />
              </div>
              <div class="w-full">
                <.input field={fa[:city]} type="text" label="Cidade" value="Porto" />
              </div>
            </.inputs_for>
          </div>
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
  def handle_event("validate", %{"family" => help_request_attrs}, socket) do
    form =
      to_form(HelpQueue.change_request_help(help_request_attrs), action: :validate)

    {:noreply, assign(socket, form: form)}
  end

  @impl true
  def handle_event("add-help-request", %{"family" => help_request_attrs}, socket) do
    case HelpQueue.request_help(help_request_attrs) do
      {:ok, created_request} ->
        send(self(), {:help_request_created, created_request})
        send(self(), {:put_flash, [:info, "Pedido de ajuda registrado!"]})
        {:noreply, socket}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end
end

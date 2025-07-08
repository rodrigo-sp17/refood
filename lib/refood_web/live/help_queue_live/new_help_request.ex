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
              <.input field={f[:adults]} type="number" label="Adultos" value={1} />
            </div>
            <div class="w-full">
              <.input field={f[:children]} type="number" label="Crianças" value={0} />
            </div>
          </div>
          <.input field={f[:phone_number]} type="tel" label="Tel." />
          <.input field={f[:email]} type="email" label="Email" />
          <div class="flex gap-4 justify-stretch">
            <div class="w-full">
              <.input field={f[:region]} type="text" label="Região" />
            </div>
            <div class="w-full">
              <.input field={f[:city]} type="text" label="Cidade" value="Porto" />
            </div>
          </div>

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
    {region, attrs} = Map.pop(help_request_attrs, "region")
    {city, attrs} = Map.pop(attrs, "city")

    sanitized_attrs = Map.merge(attrs, %{"address" => %{"region" => region, "city" => city}})

    case Families.request_help(sanitized_attrs) do
      {:ok, created_request} ->
        socket.assigns.on_created.(created_request)
        {:noreply, put_flash(socket, :info, "Pedido de ajuda registrado!")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end
end

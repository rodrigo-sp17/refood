defmodule RefoodWeb.StoragesLive.NewStorage do
  @moduledoc """
  Adds a new storage to the list.
  """
  use RefoodWeb, :live_component

  alias Refood.Inventory.Storage
  alias Refood.Inventory.Storages

  @impl true
  def mount(socket) do
    assigns = [
      changeset: Storages.change(%Storage{})
    ]

    {:ok, assign(socket, assigns)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.modal show id={@id} on_cancel={@on_cancel}>
        <.header>
          Novo Inventário
          <:subtitle>Exemplo: Cozinha, Frigorífico 1, etc.</:subtitle>
        </.header>

        <.simple_form :let={f} for={@changeset} phx-target={@myself} phx-submit="add-storage">
          <.input field={f[:name]} label="Nome" />
          <.error :if={@changeset.action}>
            Oops, algo de errado aconteceu!
          </.error>

          <:actions>
            <.button>Salvar</.button>
          </:actions>
        </.simple_form>
      </.modal>
    </div>
    """
  end

  @impl true
  def handle_event("add-storage", %{"storage" => storage_attrs}, socket) do
    case Storages.create(storage_attrs) do
      {:ok, storage} ->
        socket.assigns.on_created.(storage)
        {:noreply, put_flash(socket, :info, "Inventário criado!")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end
end

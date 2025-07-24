defmodule RefoodWeb.HelpQueueLive.ChangeQueuePosition do
  @moduledoc """
  Component to change the queue order of a family.
  """
  use RefoodWeb, :live_component

  alias Refood.Families.HelpQueue

  @impl true
  def update(assigns, socket) do
    updated_assigns =
      Map.merge(assigns, %{
        form: to_form(%{"old_position" => nil, "new_position" => nil})
      })

    {:ok, assign(socket, updated_assigns)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.modal show id={@id} on_cancel={@on_cancel}>
        <.header>
          Trocar posição de {@family.name}
        </.header>
        <.simple_form :let={f} for={@form} phx-target={@myself} phx-submit="change-queue-position">
          <div class="flex flex-row justify-start gap-8">
            <.input
              field={f[:old_position]}
              readonly
              disabled
              value={@family.queue_position}
              label="De"
            />
            <.input
              field={f[:new_position]}
              type="number"
              step="1"
              min="1"
              pattern="[0-9]*"
              label="Para"
            />
          </div>
          <.error :if={@form.action}>
            Oops, algo de errado aconteceu!
          </.error>

          <:actions>
            <.button class="w-full">Trocar</.button>
          </:actions>
        </.simple_form>
      </.modal>
    </div>
    """
  end

  @impl true
  def handle_event("change-queue-position", %{"new_position" => new_position}, socket) do
    case HelpQueue.move_queue_position(socket.assigns.family.id, new_position) do
      {:ok, created_request} ->
        socket.assigns.on_created.(created_request)
        {:noreply, put_flash(socket, :info, "Posição trocada!")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end
end

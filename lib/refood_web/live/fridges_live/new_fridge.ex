defmodule RefoodWeb.FridgesLive.NewFridge do
  use RefoodWeb, :live_component

  alias Refood.Fridges

  @impl true
  def update(assigns, socket) do
    {:ok, assign(socket, assigns |> Map.put(:form, to_form(Fridges.change_fridge())))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.modal show id={@id} on_cancel={@on_cancel}>
        <:header>Gerir Frigoríficos</:header>
        <div :if={Enum.any?(@fridges)} class="mb-6">
          <h3 class="text-sm font-semibold text-zinc-700 mb-2">Frigoríficos existentes</h3>
          <ul class="divide-y divide-zinc-100 border border-zinc-200 rounded-lg overflow-hidden">
            <li :for={fridge <- @fridges} class="flex items-center justify-between px-4 py-3 text-sm">
              <span class="font-medium text-zinc-900">{fridge.name}</span>
              <.link
                patch={~p"/fridges?delete-fridge&fridge_id=#{fridge.id}"}
                class="text-rose-600 hover:text-rose-800 text-xs font-medium"
              >
                Eliminar
              </.link>
            </li>
          </ul>
        </div>
        <.simple_form
          id="new-fridge-form"
          for={@form}
          phx-change="validate"
          phx-target={@myself}
          phx-submit="create-fridge"
        >
          <.input field={@form[:name]} type="text" label="Adicionar frigorífico" />
          <:actions>
            <.button class="w-full">Adicionar</.button>
          </:actions>
        </.simple_form>
      </.modal>
    </div>
    """
  end

  @impl true
  def handle_event("validate", %{"fridge" => attrs}, socket) do
    form =
      to_form(Fridges.change_fridge() |> Ecto.Changeset.cast(attrs, [:name]), action: :validate)

    {:noreply, assign(socket, form: form)}
  end

  @impl true
  def handle_event("create-fridge", %{"fridge" => attrs}, socket) do
    case Fridges.create_fridge(attrs) do
      {:ok, fridge} ->
        socket.assigns.on_created.(fridge)
        {:noreply, socket}

      {:error, changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end
end

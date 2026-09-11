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
      <.modal show id={@id} on_cancel={@on_cancel} size={:md}>
        <:header>Gerir frigoríficos</:header>
        <:footer>
          <div class="flex justify-end gap-3">
            <.button type="button" variant={:ghost} phx-click={@on_cancel}>Fechar</.button>
            <.button type="submit" form="new-fridge-form">Adicionar frigorífico</.button>
          </div>
        </:footer>

        <div class="flex flex-col gap-8">
          <.record_list
            id="fridges-list"
            title="Frigoríficos"
            items={@fridges}
            empty_message="Nenhum frigorífico registado"
          >
            <:item :let={fridge}>
              <span class="font-medium text-zinc-900">{fridge.name}</span>
              <.link
                patch={~p"/fridges?delete-fridge&fridge_id=#{fridge.id}"}
                class="text-sm font-medium text-rose-600 hover:text-rose-800"
              >
                Eliminar
              </.link>
            </:item>
          </.record_list>

          <.record_form
            :let={rf}
            id="new-fridge-form"
            for={@form}
            phx-change="validate"
            phx-target={@myself}
            phx-submit="create-fridge"
          >
            <.section title="Adicionar">
              <.field rf={rf} name={:name} label="Nome" width={:md} required />
            </.section>
          </.record_form>
        </div>
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

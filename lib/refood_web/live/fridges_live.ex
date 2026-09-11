defmodule RefoodWeb.FridgesLive do
  use RefoodWeb, :live_view

  alias Refood.Format
  alias Refood.Fridges
  alias RefoodWeb.FridgesLive.NewFridge
  alias RefoodWeb.FridgesLive.NewTemperatureRecord

  @impl true
  def mount(_params, _session, socket) do
    assigns = [
      fridges: Fridges.list_fridges(),
      records: Fridges.list_temperature_records(),
      view_to_show: nil,
      selected_fridge: nil,
      selected_datetime: nil
    ]

    {:ok, assign(socket, assigns)}
  end

  @impl true
  def handle_params(%{"new-fridge" => _}, _uri, socket) do
    with {:ok, socket} <- authorize(socket, [:manager, :admin]) do
      {:noreply, assign(socket, view_to_show: :new_fridge)}
    end
  end

  @impl true
  def handle_params(%{"new-record" => _}, _uri, socket) do
    {:noreply, assign(socket, view_to_show: :new_record, selected_datetime: nil)}
  end

  @impl true
  def handle_params(%{"edit-record" => _, "datetime" => datetime_str}, _uri, socket) do
    with {:ok, socket} <- authorize(socket, [:manager, :admin]),
         {:ok, datetime} <- NaiveDateTime.from_iso8601(datetime_str) do
      {:noreply, assign(socket, view_to_show: :edit_record, selected_datetime: datetime)}
    else
      _ -> {:noreply, push_patch(socket, to: ~p"/fridges")}
    end
  end

  @impl true
  def handle_params(%{"delete-fridge" => _, "fridge_id" => fridge_id}, _uri, socket) do
    with {:ok, socket} <- authorize(socket, [:manager, :admin]) do
      fridge = Fridges.get_fridge!(fridge_id)
      {:noreply, assign(socket, view_to_show: :confirm_delete_fridge, selected_fridge: fridge)}
    end
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply, assign(socket, view_to_show: nil, selected_fridge: nil, selected_datetime: nil)}
  end

  @impl true
  def handle_event("hide-view", _, socket) do
    {:noreply, push_patch(socket, to: ~p"/fridges")}
  end

  @impl true
  def handle_event("delete-fridge", _, socket) do
    fridge = socket.assigns.selected_fridge

    case Fridges.delete_fridge(fridge) do
      {:ok, _} ->
        socket =
          socket
          |> put_flash(:info, "Frigorífico eliminado.")
          |> assign(fridges: Fridges.list_fridges(), records: Fridges.list_temperature_records())

        {:noreply, push_patch(socket, to: ~p"/fridges")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Erro ao eliminar frigorífico.")}
    end
  end

  defp reload(socket) do
    assign(socket,
      fridges: Fridges.list_fridges(),
      records: Fridges.list_temperature_records()
    )
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex flex-col h-full">
      <.header>
        Frigoríficos
        <:actions>
          <div class="flex gap-2">
            <.link patch={~p"/fridges?new-record"}>
              <.button>Registar Temperaturas</.button>
            </.link>
            <.link :if={@current_user.role in [:admin, :manager]} patch={~p"/fridges?new-fridge"}>
              <.button>Gerir Frigoríficos</.button>
            </.link>
          </div>
        </:actions>
      </.header>

      <.table :if={@records != []} id="fridges-table" rows={@records}>
        <:col :let={{datetime, _records_by_fridge}} label="Data e Hora">
          {Format.datetime(datetime)}
        </:col>
        <:col :let={{_datetime, records_by_fridge}} :for={fridge <- @fridges} label={fridge.name}>
          {case Map.get(records_by_fridge, fridge.id) do
            nil -> "—"
            r -> "#{Decimal.to_string(r.temperature)}°C"
          end}
        </:col>
        <:action :let={{datetime, _records_by_fridge}} :if={@current_user.role in [:admin, :manager]}>
          <.link patch={~p"/fridges/?edit-record&datetime=#{NaiveDateTime.to_iso8601(datetime)}"}>
            Editar
          </.link>
        </:action>
      </.table>
      <div :if={@records == []} class="mt-11 py-6 text-center text-sm text-zinc-500">
        Nenhum registo encontrado.
      </div>

      <.live_component
        :if={@view_to_show == :new_fridge}
        module={NewFridge}
        id="new-fridge"
        fridges={@fridges}
        on_cancel={JS.push("hide-view")}
        on_created={
          fn _fridge ->
            send(self(), {:fridge_created})
          end
        }
      />

      <.live_component
        :if={@view_to_show in [:new_record, :edit_record]}
        module={NewTemperatureRecord}
        id="new-temperature-record"
        fridges={@fridges}
        datetime={@selected_datetime}
        on_cancel={JS.push("hide-view")}
        on_saved={fn -> send(self(), {:records_saved}) end}
      />

      <.confirmation_modal
        :if={@view_to_show == :confirm_delete_fridge}
        id="confirm-delete-fridge"
        question={"Eliminar o frigorífico \"#{@selected_fridge && @selected_fridge.name}\"? Todos os registos de temperatura serão eliminados."}
        type={:delete}
        confirm_text="Eliminar"
        deny_text="Cancelar"
        on_confirm={JS.push("delete-fridge")}
        on_cancel={JS.push("hide-view")}
      />
    </div>
    """
  end

  @impl true
  def handle_info({:fridge_created}, socket) do
    socket =
      socket
      |> put_flash(:info, "Frigorífico criado.")
      |> reload()

    {:noreply, push_patch(socket, to: ~p"/fridges")}
  end

  @impl true
  def handle_info({:records_saved}, socket) do
    socket =
      socket
      |> put_flash(:info, "Temperaturas guardadas.")
      |> reload()

    {:noreply, push_patch(socket, to: ~p"/fridges")}
  end
end

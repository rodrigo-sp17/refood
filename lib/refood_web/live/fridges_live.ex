defmodule RefoodWeb.FridgesLive do
  use RefoodWeb, :live_view

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
      <div class="flex items-center justify-between">
        <h1 class="text-2xl font-semibold">Frigoríficos</h1>
        <div class="flex gap-2">
          <.link patch={~p"/fridges?new-record"}>
            <.button>Registar Temperaturas</.button>
          </.link>
          <.link :if={@current_user.role in [:admin, :manager]} patch={~p"/fridges?new-fridge"}>
            <.button>Gerir Frigoríficos</.button>
          </.link>
        </div>
      </div>

      <div class="overflow-y-auto mt-8 bg-white rounded-xl shadow-sm">
        <table class="w-full">
          <thead>
            <tr class="border-b border-zinc-200">
              <th class="py-4 pl-6 pr-4 text-left text-sm font-semibold text-zinc-900 whitespace-nowrap">
                Data e Hora
              </th>
              <th
                :for={fridge <- @fridges}
                class="py-4 px-4 text-left text-sm font-semibold text-zinc-900 whitespace-nowrap"
              >
                {fridge.name}
              </th>
              <th
                :if={@current_user.role in [:admin, :manager]}
                class="relative py-4 pl-4 pr-6 text-right"
              >
                <span class="sr-only">Ações</span>
              </th>
            </tr>
          </thead>
          <tbody class="divide-y divide-zinc-100">
            <tr :if={Enum.empty?(@records)} class="text-sm text-zinc-500">
              <td class="py-6 pl-6" colspan={length(@fridges) + 2}>
                Nenhum registo encontrado.
              </td>
            </tr>
            <tr :for={{datetime, records_by_fridge} <- @records} class="hover:bg-zinc-50 group">
              <td class="py-4 pl-6 pr-4 text-sm text-zinc-900 whitespace-nowrap">
                {Calendar.strftime(datetime, "%d/%m/%Y %H:%M:%S")}
              </td>
              <td :for={fridge <- @fridges} class="py-4 px-4 text-sm text-zinc-700 whitespace-nowrap">
                {case Map.get(records_by_fridge, fridge.id) do
                  nil -> "—"
                  r -> "#{Decimal.to_string(r.temperature)}°C"
                end}
              </td>
              <td
                :if={@current_user.role in [:admin, :manager]}
                class="py-4 pl-4 pr-6 text-right text-sm whitespace-nowrap"
              >
                <.link
                  patch={~p"/fridges/?edit-record&datetime=#{NaiveDateTime.to_iso8601(datetime)}"}
                  class="text-zinc-600 hover:text-zinc-900 underline"
                >
                  Editar
                </.link>
              </td>
            </tr>
          </tbody>
        </table>
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

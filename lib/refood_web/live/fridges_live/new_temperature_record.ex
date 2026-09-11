defmodule RefoodWeb.FridgesLive.NewTemperatureRecord do
  use RefoodWeb, :live_component

  alias Refood.Fridges

  @impl true
  def update(%{fridges: fridges, datetime: datetime} = assigns, socket) do
    params =
      fridges
      |> existing_temperatures(datetime)
      |> Map.put("recorded_at", default_recorded_at(datetime))

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:form, to_form(params, as: :records))}
  end

  defp existing_temperatures(fridges, nil) do
    Map.new(fridges, fn fridge -> {field_name(fridge), ""} end)
  end

  defp existing_temperatures(fridges, datetime) do
    Map.new(fridges, fn fridge ->
      record = Fridges.get_record_for_datetime(fridge.id, datetime)
      {field_name(fridge), if(record, do: Decimal.to_string(record.temperature), else: "")}
    end)
  end

  defp field_name(fridge), do: "fridge_#{fridge.id}"

  defp default_recorded_at(nil) do
    DateTime.utc_now() |> DateTime.to_naive() |> datetime_to_input()
  end

  defp default_recorded_at(datetime), do: datetime_to_input(datetime)

  defp datetime_to_input(naive), do: naive |> NaiveDateTime.to_iso8601() |> binary_part(0, 16)

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.modal show id={@id} on_cancel={@on_cancel} size={:md}>
        <:header>Registar temperaturas</:header>
        <:subtitle>Deixe em branco os frigoríficos que não foram medidos.</:subtitle>
        <:footer>
          <div class="flex justify-end gap-3">
            <.button type="button" variant={:ghost} phx-click={@on_cancel}>Cancelar</.button>
            <.button type="submit" form="new-temperature-form">Guardar leituras</.button>
          </div>
        </:footer>
        <.record_form
          :let={rf}
          id="new-temperature-form"
          for={@form}
          phx-submit="save-records"
          phx-target={@myself}
        >
          <.section title="Leitura">
            <.field rf={rf} name={:recorded_at} label="Data e hora" type="datetime-local" width={:sm} />
          </.section>

          <.section title="Frigoríficos">
            <.field
              :for={fridge <- @fridges}
              rf={rf}
              name={String.to_atom(field_name(fridge))}
              label={"#{fridge.name} (°C)"}
              type="number"
              width={:xs}
              step="0.1"
              placeholder="—"
            />
          </.section>
        </.record_form>
      </.modal>
    </div>
    """
  end

  @impl true
  def handle_event("save-records", %{"records" => params}, socket) do
    recorded_at = parse_recorded_at(Map.get(params, "recorded_at", ""))
    fridges = socket.assigns.fridges

    errors =
      Enum.flat_map(fridges, fn fridge ->
        case Map.get(params, field_name(fridge), "") do
          "" ->
            []

          temperature ->
            case Fridges.upsert_record(fridge.id, recorded_at, temperature) do
              {:ok, _record} -> []
              {:error, _changeset} -> [{String.to_atom(field_name(fridge)), {message(), []}}]
            end
        end
      end)

    if errors == [] do
      socket.assigns.on_saved.()
      {:noreply, socket}
    else
      {:noreply, assign(socket, form: to_form(params, as: :records, errors: errors))}
    end
  end

  # Every way a reading can be rejected comes down to the same fix, so say that
  # rather than surfacing the field name and a raw Ecto message.
  defp message, do: "Introduza uma temperatura válida, por exemplo 4,5."

  defp parse_recorded_at("") do
    DateTime.utc_now() |> DateTime.truncate(:second)
  end

  defp parse_recorded_at(str) do
    case NaiveDateTime.from_iso8601(str <> ":00") do
      {:ok, naive} -> DateTime.from_naive!(naive, "Etc/UTC")
      _ -> DateTime.utc_now() |> DateTime.truncate(:second)
    end
  end
end

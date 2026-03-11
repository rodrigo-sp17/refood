defmodule RefoodWeb.FridgesLive.NewTemperatureRecord do
  use RefoodWeb, :live_component

  alias Refood.Fridges

  @impl true
  def update(%{fridges: fridges, datetime: datetime} = assigns, socket) do
    existing = build_existing_map(fridges, datetime)

    {:ok,
     assign(socket, assigns)
     |> assign(:existing, existing)
     |> assign(:recorded_at, default_recorded_at(datetime))
     |> assign(:errors, %{})}
  end

  defp build_existing_map(fridges, nil) do
    Map.new(fridges, fn fridge -> {fridge.id, ""} end)
  end

  defp build_existing_map(fridges, datetime) do
    Map.new(fridges, fn fridge ->
      record = Fridges.get_record_for_datetime(fridge.id, datetime)
      temp = if record, do: Decimal.to_string(record.temperature), else: ""
      {fridge.id, temp}
    end)
  end

  defp default_recorded_at(nil) do
    DateTime.utc_now() |> datetime_to_local_input()
  end

  defp default_recorded_at(datetime) do
    datetime |> NaiveDateTime.to_iso8601() |> binary_part(0, 16)
  end

  defp datetime_to_local_input(dt) do
    dt |> DateTime.to_naive() |> NaiveDateTime.to_iso8601() |> binary_part(0, 16)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.modal show id={@id} on_cancel={@on_cancel}>
        <:header>Registar Temperaturas</:header>
        <form id="new-temperature-form" phx-submit="save-records" phx-target={@myself}>
          <div class="flex flex-col gap-4 mt-4">
            <div>
              <label class="block text-sm font-semibold leading-6 text-zinc-800 mb-1">
                Data e Hora
              </label>
              <input
                type="datetime-local"
                name="records[recorded_at]"
                value={@recorded_at}
                class="block w-full rounded-lg text-zinc-900 focus:ring-0 sm:text-sm sm:leading-6 border border-zinc-300 focus:border-zinc-400 py-[7px] px-[11px]"
              />
            </div>
            <div :for={fridge <- @fridges} class="flex gap-4 items-end">
              <div class="flex-1">
                <label class="block text-sm font-semibold leading-6 text-zinc-800 mb-1">
                  {fridge.name} (°C)
                </label>
                <input
                  type="number"
                  step="0.1"
                  name={"records[fridge_#{fridge.id}]"}
                  value={Map.get(@existing, fridge.id, "")}
                  placeholder="—"
                  class="block w-full rounded-lg text-zinc-900 focus:ring-0 sm:text-sm sm:leading-6 border border-zinc-300 focus:border-zinc-400 py-[7px] px-[11px]"
                />
                <p :if={Map.get(@errors, fridge.id)} class="mt-1 text-sm text-rose-600">
                  {Map.get(@errors, fridge.id)}
                </p>
              </div>
            </div>
            <div class="mt-2">
              <.button class="w-full">Guardar</.button>
            </div>
          </div>
        </form>
      </.modal>
    </div>
    """
  end

  @impl true
  def handle_event("save-records", %{"records" => params}, socket) do
    recorded_at = parse_recorded_at(Map.get(params, "recorded_at", ""))
    fridges = socket.assigns.fridges

    results =
      Enum.map(fridges, fn fridge ->
        key = "fridge_#{fridge.id}"

        case Map.get(params, key, "") do
          "" -> {:ok, :skipped}
          temp -> Fridges.upsert_record(fridge.id, recorded_at, temp)
        end
      end)

    errors =
      fridges
      |> Enum.zip(results)
      |> Enum.reduce(%{}, fn {fridge, result}, acc ->
        case result do
          {:error, changeset} ->
            msg =
              changeset.errors |> Enum.map(fn {f, {m, _}} -> "#{f}: #{m}" end) |> Enum.join(", ")

            Map.put(acc, fridge.id, msg)

          _ ->
            acc
        end
      end)

    if Enum.empty?(errors) do
      socket.assigns.on_saved.()
      {:noreply, socket}
    else
      {:noreply, assign(socket, errors: errors)}
    end
  end

  defp parse_recorded_at("") do
    DateTime.utc_now() |> DateTime.truncate(:second)
  end

  defp parse_recorded_at(str) do
    case NaiveDateTime.from_iso8601(str <> ":00") do
      {:ok, ndt} -> DateTime.from_naive!(ndt, "Etc/UTC")
      _ -> DateTime.utc_now() |> DateTime.truncate(:second)
    end
  end
end

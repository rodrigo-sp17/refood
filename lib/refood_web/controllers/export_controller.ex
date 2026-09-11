defmodule RefoodWeb.ExportController do
  use RefoodWeb, :controller

  alias Refood.Families
  alias Refood.Families.Family
  alias Refood.Families.HelpQueue
  alias Refood.Format
  alias Refood.Inventory.Storages
  alias Refood.Repo

  plug RefoodWeb.Plugs.Authorize,
       [:admin, :manager] when action in [:download_help_queue_csv, :download_families_csv]

  def download_help_queue_csv(conn, _params) do
    families = HelpQueue.list_queue()

    header = [
      "Pedido em",
      "ID",
      "Nome",
      "Adultos",
      "Crianças",
      "Telefone",
      "Email",
      "Fala portugues",
      "Notas",
      "Morada",
      "Região",
      "Cidade",
      "Código Postal"
    ]

    rows =
      Enum.map(families, fn family ->
        address = family.address

        [
          family.help_requested_at &&
            Format.datetime(family.help_requested_at),
          String.slice(family.id, 0, 6),
          family.name,
          family.adults,
          family.children,
          family.phone_number,
          family.email,
          family.speaks_portuguese,
          family.notes,
          format_address(address),
          address && address.region,
          address && address.city,
          address && address.zipcode
        ]
      end)

    filename = "lista_de_espera_#{timestamp()}.csv"
    send_csv(conn, filename, header, rows)
  end

  def download_families_csv(conn, _params) do
    families = Families.list_families() |> Repo.preload(:address)

    header = [
      "ID",
      "No.",
      "Nome",
      "Alertas",
      "Email",
      "Telefone",
      "NIF",
      "NISS",
      "CC",
      "Adultos",
      "Crianças",
      "Restrições",
      "Notas",
      "Dias",
      "Faltas",
      "Morada",
      "Região",
      "Cidade",
      "Código Postal",
      "Ajuda pedida em"
    ]

    rows =
      Enum.map(families, fn family ->
        address = family.address

        alerts =
          Enum.map_join(family.active_alerts, ", ", &Refood.Families.Alert.type_to_name(&1.type))

        [
          String.slice(family.id, 0, 8),
          family.number && "F-#{family.number}",
          family.name,
          alerts,
          family.email,
          family.phone_number,
          family.nif,
          family.niss,
          family.cc,
          family.adults,
          family.children,
          family.restrictions,
          family.notes,
          family.weekdays && Family.get_readable_weekdays(family, :short),
          length(family.absences),
          format_address(address),
          address && address.region,
          address && address.city,
          address && address.zipcode,
          family.help_requested_at &&
            Format.datetime(family.help_requested_at)
        ]
      end)

    filename = "familias_#{timestamp()}.csv"
    send_csv(conn, filename, header, rows)
  end

  def download_storage_csv(conn, %{"storage_id" => storage_id}) do
    storage = Storages.get_storage!(storage_id)

    # TODO -> add quantity
    header = [:product, :expires_at]
    rows = Enum.map(storage.items, fn item -> [item.product.name, item.expires_at] end)

    send_csv(conn, "download.csv", header, rows)
  end

  defp send_csv(conn, filename, header, rows) do
    file =
      [header | rows]
      |> CSV.encode()
      |> Enum.to_list()
      |> List.to_string()

    # UTF-8 BOM for Excel compatibility with Portuguese characters
    bom = "\uFEFF"

    conn
    |> put_resp_content_type("text/csv")
    |> put_resp_header("content-disposition", ~s(attachment; filename="#{filename}"))
    |> put_root_layout(false)
    |> send_resp(200, bom <> file)
  end

  defp format_address(nil), do: nil

  defp format_address(address) do
    [address.line_1, address.line_2]
    |> Enum.reject(&is_nil/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.join(", ")
  end

  defp timestamp do
    Calendar.strftime(DateTime.utc_now(), "%Y-%m-%d_%H-%M")
  end
end

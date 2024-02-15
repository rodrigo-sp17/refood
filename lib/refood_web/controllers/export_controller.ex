defmodule RefoodWeb.ExportController do
  use RefoodWeb, :controller

  alias Refood.Inventory.Storages

  def download_storage_csv(conn, %{"storage_id" => storage_id}) do
    storage = Storages.get_storage!(storage_id)

    # TODO -> add quantity
    columns = [:product, :expires_at]

    file =
      storage.items
      |> Enum.reduce([columns], fn item, acc ->
        [[item.product.name, item.expires_at] | acc]
      end)
      |> CSV.encode()
      |> Enum.reverse()
      |> Enum.to_list()
      |> List.to_string()

    conn
    |> put_resp_content_type("text/csv")
    |> put_resp_header("content-disposition", "attachment; filename=\"download.csv\"")
    |> put_root_layout(false)
    |> send_resp(200, file)
  end
end

defmodule RefoodWeb.Layouts do
  use RefoodWeb, :html

  embed_templates "layouts/*"

  defp nav_item_class(active?, opts \\ []) do
    layout =
      if Keyword.get(opts, :compact, false) do
        "flex justify-center items-center h-16 p-4 my-1"
      else
        "flex gap-3 items-center h-16 w-full p-4 my-1 font-medium"
      end

    state =
      if active?,
        do: "bg-brand text-zinc-900 rounded-sm",
        else: "text-white hover:bg-zinc-500 hover:rounded"

    "#{layout} #{state}"
  end
end

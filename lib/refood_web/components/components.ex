defmodule RefoodWeb.Components do
  use RefoodWeb, :html

  attr :active_tab, :atom, values: [:products, :storages]

  def nav_bar(assigns) do
    ~H"""
    <nav class="fixed bg-black h-full w-60 flex flex-col content-stretch gap-1 px-4 py-1 space-y-1">
      <div class="h-20 flex items-center p-4 text-yellow-500 text-left font-extrabold text-2xl">
        REFOOD
      </div>
      <.link
        class={"#{if @active_tab == :storages, do: "bg-gray-500 rounded"}"}
        navigate={~p"/storages"}
      >
        <div class="flex gap-5 items-center h-16 w-full p-4 font-semibold text-yellow-500 hover:bg-gray-500 hover:rounded">
          <.icon name="hero-folder-solid" /> Inventários
        </div>
      </.link>
      <.link
        class={"#{if @active_tab == :products, do: "bg-gray-500 rounded"}"}
        navigate={~p"/products"}
      >
        <div class="flex gap-5 items-center h-16 w-full p-4 font-semibold text-yellow-500 hover:bg-gray-500 hover:rounded">
          <.icon name="hero-book-open-solid" /> Produtos
        </div>
      </.link>
    </nav>
    """
  end
end

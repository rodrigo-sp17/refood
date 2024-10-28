defmodule RefoodWeb.FamiliesLive do
  @moduledoc """
  Manages all available families.
  """
  use RefoodWeb, :live_view

  alias Refood.Families
  alias Refood.Families.Family

  @impl true
  def mount(_params, _session, socket) do
    assigns = [
      families: Families.list_families(),
      view_to_show: nil,
      sort: %{},
      filter: ""
    ]

    {:ok, assign(socket, assigns)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.header>
      Famílias
      <:actions>
        <.button phx-click="show-new-family">Nova Família</.button>
      </:actions>
    </.header>
    <div class="mt-11 bg-white rounded-xl">
      <.table id="families" rows={@families} row_click={&JS.push("show-family", value: %{id: &1.id})}>
        <:top_controls>
          <div class="flex items-center justify-between p-4">
            <.table_search_input value={@filter} on_change="on-filter" on_reset="on-reset-filter" />
          </div>
        </:top_controls>
        <:col :let={family} id="family-id" sort={@sort[:id]} on_sort={&on_sort(:id, &1)} label="ID">
          <%= String.slice(family.id, 0, 8) %>
        </:col>
        <:col
          :let={family}
          id="number"
          sort={@sort[:number]}
          on_sort={&on_sort(:number, &1)}
          label="No."
        >
          <%= "F-#{family.number}" %>
        </:col>
        <:col :let={family} id="name" sort={@sort[:name]} on_sort={&on_sort(:name, &1)} label="Nome">
          <%= family.name %>
        </:col>
        <:col
          :let={family}
          id="adults"
          sort={@sort[:adults]}
          on_sort={&on_sort(:adults, &1)}
          label="Adultos"
        >
          <%= family.adults %>
        </:col>
        <:col
          :let={family}
          id="children"
          sort={@sort[:children]}
          on_sort={&on_sort(:children, &1)}
          label="Crianças"
        >
          <%= family.children %>
        </:col>
        <:col
          :let={family}
          id="restrictions"
          sort={@sort[:restrictions]}
          on_sort={&on_sort(:restrictions, &1)}
          label="Restrições"
        >
          <%= family.restrictions %>
        </:col>
        <:col
          :let={family}
          id="weekdays"
          sort={@sort[:weekdays]}
          on_sort={&on_sort(:weekdays, &1)}
          label="Dias"
        >
          <%= Family.get_readable_weekdays(family, :short) %>
        </:col>
        <:col
          :let={family}
          id="absences"
          sort={@sort[:absences]}
          on_sort={&on_sort(:absences, &1)}
          label="Faltas"
        >
          <%= length(family.absences) %>
        </:col>
        <:action :let={family}>
          <.link phx-click="show-edit-family" phx-value-id={family.id}>
            <.icon name="hero-pencil" class="h-5 w-5 hover:bg-blue-500" />
          </.link>
        </:action>
      </.table>
    </div>
    """
  end

  defp on_sort(col_id, sort), do: JS.push("on-sort", value: %{id: col_id, sort: sort})

  @impl true
  def handle_event("on-sort", %{"id" => col_id, "sort" => sort}, socket) do
    col_id = String.to_existing_atom(col_id)
    sort = sort && String.to_existing_atom(sort)

    new_sort =
      case sort do
        nil -> %{}
        sort -> Map.new([{col_id, sort}])
      end

    assigns = [
      sort: new_sort,
      families: sort_families(socket.assigns.families, col_id, sort)
    ]

    {:noreply, assign(socket, assigns)}
  end

  @impl true
  def handle_event("on-filter", %{"value" => value}, socket) do
    assigns = [
      filter: value,
      families: Families.list_families(%{q: value})
    ]

    {:noreply, assign(socket, assigns)}
  end

  @impl true
  def handle_event("on-reset-filter", _, socket) do
    assigns = [
      filter: "",
      families: Families.list_families()
    ]

    {:noreply, assign(socket, assigns)}
  end

  defp sort_families(families, _key, nil), do: families
  defp sort_families(families, key, order), do: Enum.sort_by(families, &Map.get(&1, key), order)
end

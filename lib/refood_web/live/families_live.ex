defmodule RefoodWeb.FamiliesLive do
  @moduledoc """
  Manages all available families.
  """
  use RefoodWeb, :live_view

  alias Refood.Families
  alias Refood.Families.Family
  alias RefoodWeb.FamiliesLive.FamilyDetails
  alias RefoodWeb.FamiliesLive.NewFamily
  alias RefoodWeb.FamiliesLive.MoveToActive

  # TODO: add confirmation for for enqueueing

  @impl true
  def mount(_params, _session, socket) do
    assigns = [
      families: Families.list_families(),
      selected_family: nil,
      view_to_show: nil,
      sort: %{},
      filter: ""
    ]

    {:ok, assign(socket, assigns)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.live_component
      :if={@view_to_show == :new_family}
      module={NewFamily}
      id="new-family"
      on_created={fn family -> send(self(), {:updated_family, family}) end}
      on_cancel={JS.push("hide-view")}
    />

    <.live_component
      :if={@view_to_show == :show_family_details}
      module={FamilyDetails}
      id="show-family-details"
      family={@selected_family}
      on_created={fn family -> send(self(), {:updated_family, family}) end}
      on_cancel={JS.push("hide-view")}
    />

    <MoveToActive.form
      :if={@view_to_show == :move_to_active}
      id="move-to-active-form"
      for={Families.change_activate_family(@selected_family, %{})}
      family={@selected_family}
      on_cancel={JS.push("hide-view")}
    />

    <.modal
      :if={@view_to_show == :move_to_finished}
      id="move-to-finished-form"
      show
      on_cancel={JS.push("hide-view")}
    >
      <div class="flex flex-col gap-10">
        <h2 class="text-2xl text-center">
          Deseja remover F-{@selected_family.number} da ajuda regular?
        </h2>
        <div class="flex justify-center gap-8 h-12">
          <button
            phx-click={JS.push("hide-view")}
            class="basis-1/3 rounded-3xl bg-transparent text-black hover:bg-black hover:text-white border border-black px-6"
          >
            Cancelar
          </button>
          <button
            phx-click="move-to-finished"
            phx-value-id={@selected_family.id}
            class="basis-1/3 rounded-3xl bg-red-500 text-white hover:bg-transparent hover:text-red-500 border border-red-500 px-6"
          >
            Remover
          </button>
        </div>
      </div>
    </.modal>

    <.header>
      Famílias
      <:actions>
        <.button phx-click="show-new-family">Criar nova família</.button>
      </:actions>
    </.header>
    <.table id="families" rows={@families} row_click={&JS.push("show-family", value: %{id: &1.id})}>
      <:top_controls>
        <div class="flex items-center justify-between p-4">
          <.table_search_input value={@filter} on_change="on-filter" on_reset="on-reset-filter" />
        </div>
      </:top_controls>
      <:col :let={family} id="family-id" sort={@sort[:id]} on_sort={&on_sort(:id, &1)} label="ID">
        {String.slice(family.id, 0, 8)}
      </:col>
      <:col
        :let={family}
        id="number"
        sort={@sort[:number]}
        on_sort={&on_sort(:number, &1)}
        label="No."
      >
        {family.number && "F-#{family.number}"}
      </:col>
      <:col :let={family} id="name" sort={@sort[:name]} on_sort={&on_sort(:name, &1)} label="Nome">
        {family.name}
      </:col>
      <:col
        :let={family}
        id="phone-number"
        sort={@sort[:phone_number]}
        on_sort={&on_sort(:phone_number, &1)}
        label="Tel."
      >
        {family.phone_number}
      </:col>
      <:col
        :let={family}
        id="adults"
        sort={@sort[:adults]}
        on_sort={&on_sort(:adults, &1)}
        label="Adultos"
      >
        {family.adults}
      </:col>
      <:col
        :let={family}
        id="children"
        sort={@sort[:children]}
        on_sort={&on_sort(:children, &1)}
        label="Crianças"
      >
        {family.children}
      </:col>
      <:col
        :let={family}
        id="restrictions"
        sort={@sort[:restrictions]}
        on_sort={&on_sort(:restrictions, &1)}
        label="Restrições"
      >
        {family.restrictions}
      </:col>
      <:col
        :let={family}
        id="weekdays"
        sort={@sort[:weekdays]}
        on_sort={&on_sort(:weekdays, &1)}
        label="Dias"
      >
        {family.weekdays && Family.get_readable_weekdays(family, :short)}
      </:col>
      <:col
        :let={family}
        id="absences"
        sort={@sort[:absences]}
        on_sort={&on_sort(:absences, &1)}
        label="Faltas"
      >
        {length(family.absences)}
      </:col>
      <:action :let={family}>
        <.dropdown id={"dropdown-" <> family.id}>
          <:link :if={family.status !== :active} on_click="activate-family" phx-value-id={family.id}>
            Iniciar ajuda
          </:link>
          <:link :if={family.status == :active} on_click="deactivate-family" phx-value-id={family.id}>
            Parar ajuda
          </:link>
          <:link on_click="enqueue-family" phx-value-id={family.id}>
            Mover para lista de espera
          </:link>
        </.dropdown>
      </:action>
    </.table>
    """
  end

  defp on_sort(col_id, sort), do: JS.push("on-sort", value: %{id: col_id, sort: sort})

  @impl true
  def handle_event("hide-view", _unsigned_params, socket) do
    {:noreply, assign(socket, :view_to_show, nil)}
  end

  @impl true
  def handle_event("show-new-family", _, socket) do
    assigns = [
      view_to_show: :new_family
    ]

    {:noreply, assign(socket, assigns)}
  end

  @impl true
  def handle_event("show-family", %{"id" => family_id}, socket) do
    assigns = [
      view_to_show: :show_family_details,
      selected_family: Families.get_family!(family_id)
    ]

    {:noreply, assign(socket, assigns)}
  end

  @impl true
  def handle_event("activate-family", %{"id" => family_id}, socket) do
    assigns = [
      view_to_show: :move_to_active,
      selected_family: Families.get_family!(family_id)
    ]

    {:noreply, assign(socket, assigns)}
  end

  @impl true
  def handle_event("move-to-active", %{"family" => attrs}, socket) do
    case Families.activate_family(socket.assigns.selected_family.id, attrs) do
      {:ok, activated_family} ->
        assigns = [
          view_to_show: nil,
          families: Families.list_families()
        ]

        {:noreply,
         socket |> put_flash(:info, "Família movida para ajuda regular!") |> assign(assigns)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  @impl true
  def handle_event("deactivate-family", %{"id" => family_id}, socket) do
    assigns = [
      view_to_show: :move_to_finished,
      selected_family: Families.get_family!(family_id)
    ]

    {:noreply, assign(socket, assigns)}
  end

  @impl true
  def handle_event("move-to-finished", %{"id" => family_id}, socket) do
    case Families.deactivate_family(family_id) do
      {:ok, _deactivated} ->
        assigns = [
          view_to_show: nil,
          families: Families.list_families()
        ]

        {:noreply,
         socket |> put_flash(:info, "Família removida da ajuda regular!") |> assign(assigns)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  @impl true
  def handle_event("enqueue-family", %{"id" => family_id}, socket) do
    case Families.move_to_queue(family_id) do
      {:ok, _enqueued} ->
        assigns = [
          view_to_show: nil,
          families: Families.list_families()
        ]

        {:noreply,
         socket |> put_flash(:info, "Família movida para lista de espera!") |> assign(assigns)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

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

  @impl true
  def handle_info({:updated_family, _}, socket) do
    assigns = [
      view_to_show: nil,
      families: Families.list_families()
    ]

    {:noreply, assign(socket, assigns)}
  end
end

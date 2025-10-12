defmodule RefoodWeb.FamiliesLive do
  @moduledoc """
  Manages all available families.
  """
  use RefoodWeb, :live_view

  alias Refood.Families
  alias Refood.Families.HelpQueue
  alias Refood.Families.Family
  alias Refood.Families.Alert
  alias RefoodWeb.FamiliesLive.FamilyDetails
  alias RefoodWeb.FamiliesLive.NewFamily
  alias RefoodWeb.FamiliesLive.MoveToActive
  alias RefoodWeb.FamiliesLive.RegisterContact

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
  def handle_params(%{"new-family" => _}, _uri, socket) do
    with {:ok, socket} <- authorize(socket, [:manager, :admin]) do
      assigns = [
        view_to_show: :new_family
      ]

      {:noreply, assign(socket, assigns)}
    end
  end

  @impl true
  def handle_params(%{"details" => _, "family_id" => family_id}, _uri, socket) do
    assigns = [
      view_to_show: :show_family_details,
      selected_family: Families.get_family!(family_id)
    ]

    {:noreply, assign(socket, assigns)}
  end

  @impl true
  def handle_params(%{"move-to-active" => _, "family_id" => family_id}, _uri, socket) do
    with {:ok, socket} <- authorize(socket, [:manager, :admin]) do
      assigns = [
        view_to_show: :move_to_active,
        selected_family: Families.get_family!(family_id)
      ]

      {:noreply, assign(socket, assigns)}
    end
  end

  @impl true
  def handle_params(%{"move-to-finished" => _, "family_id" => family_id}, _uri, socket) do
    with {:ok, socket} <- authorize(socket, [:manager, :admin]) do
      assigns = [
        view_to_show: :confirm_move_to_finished,
        selected_family: Families.get_family!(family_id)
      ]

      {:noreply, assign(socket, assigns)}
    end
  end

  @impl true
  def handle_params(%{"move-to-queue" => _, "family_id" => family_id}, _uri, socket) do
    with {:ok, socket} <- authorize(socket, [:manager, :admin]) do
      assigns = [
        view_to_show: :confirm_enqueue_family,
        selected_family: Families.get_family!(family_id)
      ]

      {:noreply, assign(socket, assigns)}
    end
  end

  @impl true
  def handle_params(%{"register-contact" => _, "family_id" => family_id}, _uri, socket) do
    with {:ok, socket} <- authorize(socket, [:manager, :admin]) do
      assigns = [
        view_to_show: :register_contact,
        selected_family: Families.get_family!(family_id)
      ]

      {:noreply, assign(socket, assigns)}
    end
  end

  @impl true
  def handle_params(_, _uri, socket) do
    {:noreply, socket}
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
      current_user={@current_user}
    />

    <.live_component
      :if={@view_to_show == :register_contact}
      module={RegisterContact}
      id="register-contact"
      family={@selected_family}
      on_cancel={JS.push("hide-view")}
      current_user={@current_user}
    />

    <MoveToActive.form
      :if={@view_to_show == :move_to_active}
      id="move-to-active-form"
      for={Families.change_reactivate_family(@selected_family, %{})}
      family={@selected_family}
      on_cancel={JS.push("hide-view")}
    />

    <.confirmation_modal
      :if={@view_to_show == :confirm_move_to_finished}
      id="confirm-move-to-finished"
      question={"Deseja remover F-#{@selected_family.number} da ajuda regular?"}
      type={:delete}
      confirm_text="Remover"
      deny_text="Cancelar"
      on_confirm={JS.push("move-to-finished", value: %{"id" => @selected_family.id})}
      on_cancel={JS.push("hide-view")}
    />

    <.confirmation_modal
      :if={@view_to_show == :confirm_enqueue_family}
      id="confirm-enqueue-family"
      question={"Deseja mover #{@selected_family.name} para a fila de espera?"}
      confirm_text="Mover"
      deny_text="Cancelar"
      on_confirm={
        JS.push("enqueue-family", value: %{"id" => @selected_family.id}, page_loading: true)
      }
      on_cancel={JS.push("hide-view")}
    />

    <.header>
      Famílias
      <:actions>
        <.link patch="/families?new-family">
          <.button :if={@current_user.role in [:admin, :manager]}>
            Criar nova família
          </.button>
        </.link>
      </:actions>
    </.header>
    <.table
      id="families"
      rows={@families}
      row_click={&JS.push("show-family", value: %{id: &1.id}, page_loading: true)}
    >
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
        id="alerts"
        sort={@sort[:alerts]}
        on_sort={&on_sort(:alerts, &1)}
        label="Alertas"
      >
        <div
          :for={alert <- family.active_alerts}
          class="px-2 py-1 border rounded-3xl border-red-500 text-red-500 text-center text-sm"
        >
          {Alert.type_to_name(alert.type)}
        </div>
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
        <.dropdown :if={@current_user.role in [:admin, :manager]} id={"dropdown-" <> family.id}>
          <:link :if={family.status !== :active} patch={"/families/#{family.id}?move-to-active"}>
            Iniciar ajuda
          </:link>
          <:link :if={family.status == :active} patch={"/families/#{family.id}?move-to-finished"}>
            Parar ajuda
          </:link>
          <:link patch={"/families/#{family.id}?move-to-queue"}>
            Mover para lista de espera
          </:link>
          <:link patch={"/families/#{family.id}?register-contact"}>
            Registar contacto
          </:link>
        </.dropdown>
      </:action>
    </.table>
    """
  end

  defp on_sort(col_id, sort), do: JS.push("on-sort", value: %{id: col_id, sort: sort})

  @impl true
  def handle_event("hide-view", _unsigned_params, socket) do
    socket = assign(socket, selected_family: nil, view_to_show: nil)
    {:noreply, push_patch(socket, to: "/families")}
  end

  @impl true
  def handle_event("show-family", %{"id" => family_id}, socket) do
    {:noreply, push_patch(socket, to: "/families/#{family_id}?details")}
  end

  @impl true
  def handle_event("move-to-active", %{"family" => attrs}, socket) do
    with {:ok, socket} <- authorize(socket, [:manager, :admin]) do
      case Families.reactivate_family(socket.assigns.selected_family.id, attrs) do
        {:ok, _activated_family} ->
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
  end

  @impl true
  def handle_event("move-to-finished", %{"id" => family_id}, socket) do
    with {:ok, socket} <- authorize(socket, [:manager, :admin]) do
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
  end

  @impl true
  def handle_event("enqueue-family", %{"id" => family_id}, socket) do
    with {:ok, socket} <- authorize(socket, [:manager, :admin]) do
      case HelpQueue.move_to_queue(family_id) do
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

  defp sort_families(families, :alerts, order),
    do: Enum.sort_by(families, &length(&1.active_alerts), order)

  defp sort_families(families, key, order), do: Enum.sort_by(families, &Map.get(&1, key), order)

  @impl true
  def handle_info({:updated_family, _}, socket) do
    assigns = [
      view_to_show: nil,
      families: Families.list_families()
    ]

    {:noreply, assign(socket, assigns)}
  end

  @impl true
  def handle_info({:loaned_item_added, family_id}, socket) do
    updated_family = Families.get_family!(family_id)

    assigns = [
      selected_family: updated_family
    ]

    {:noreply, assign(socket, assigns)}
  end
end

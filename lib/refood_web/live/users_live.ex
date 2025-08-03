defmodule RefoodWeb.UsersLive do
  @moduledoc """
  Manages all non-admin accounts on system. Only admins can modify accounts.

  Admin accounts must be requested ad-hoc.
  """

  use RefoodWeb, :live_view

  alias Refood.Accounts
  alias RefoodWeb.UsersLive.NewUser
  alias RefoodWeb.UsersLive.UserDetails

  @impl true
  def mount(_params, _session, socket) do
    assigns = [
      users: Accounts.list_users(socket.assigns.current_user),
      selected_user: nil,
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
      :if={@view_to_show == :new_user}
      module={NewUser}
      id="new-user"
      current_user={@current_user}
      on_cancel={JS.push("hide-view")}
    />

    <.live_component
      :if={@view_to_show == :show_user_details}
      module={UserDetails}
      id="show-user-details"
      user={@selected_user}
      current_user={@current_user}
      on_cancel={JS.push("hide-view")}
    />

    <.confirmation_modal
      :if={@view_to_show == :confirm_delete_user}
      id="confirm-delete-user"
      type={:delete}
      question={"Deseja remover permanentemente o usuário #{@selected_user.name}?"}
      confirm_text="Remover"
      deny_text="Cancelar"
      on_confirm={JS.push("delete-user", value: %{"id" => @selected_user.id}, page_loading: true)}
      on_cancel={JS.push("hide-view")}
    />

    <.header>
      Usuários
      <:actions>
        <.button phx-click="show-new-user">Criar novo usuário</.button>
      </:actions>
    </.header>
    <.table
      id="users"
      rows={@users}
      row_click={
        &(&1.role != :admin && JS.push("show-user-details", value: %{id: &1.id}, page_loading: true))
      }
    >
      <:top_controls>
        <div class="flex items-center justify-between p-4">
          <.table_search_input value={@filter} on_change="on-filter" on_reset="on-reset-filter" />
        </div>
      </:top_controls>
      <:col :let={user} id="user-id" sort={@sort[:id]} on_sort={&on_sort(:id, &1)} label="ID">
        {String.slice(user.id, 0, 8)}
      </:col>
      <:col :let={user} id="name" sort={@sort[:name]} on_sort={&on_sort(:name, &1)} label="Nome">
        {user.name}
      </:col>
      <:col :let={user} id="role" sort={@sort[:role]} on_sort={&on_sort(:role, &1)} label="Função">
        {user.role}
      </:col>
      <:col :let={user} id="email" sort={@sort[:email]} on_sort={&on_sort(:email, &1)} label="Email">
        {user.email}
      </:col>
      <:col
        :let={user}
        id="confirmed-at"
        sort={@sort[:confirmed_at]}
        on_sort={&on_sort(:confirmed_at, &1)}
        label="Confirmado em"
      >
        {user.confirmed_at}
      </:col>
      <:col
        :let={user}
        id="inserted-at"
        sort={@sort[:inserted_at]}
        on_sort={&on_sort(:inserted_at, &1)}
        label="Criado em"
      >
        {user.inserted_at}
      </:col>
      <:action :let={user}>
        <.dropdown :if={user.role !== :admin} id={"dropdown-" <> user.id}>
          <:link
            :if={user.role !== :admin}
            on_click={JS.push("confirm-delete-user", value: %{id: user.id}, page_loading: true)}
          >
            Deletar usuário
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
  def handle_event("show-new-user", _, socket) do
    assigns = [
      view_to_show: :new_user
    ]

    {:noreply, assign(socket, assigns)}
  end

  @impl true
  def handle_event("show-user-details", %{"id" => user_id}, socket) do
    assigns = [
      view_to_show: :show_user_details,
      selected_user: Accounts.get_editable_user!(socket.assigns.current_user, user_id)
    ]

    {:noreply, assign(socket, assigns)}
  end

  @impl true
  def handle_event("confirm-delete-user", %{"id" => user_id}, socket) do
    assigns = [
      view_to_show: :confirm_delete_user,
      selected_user: Accounts.get_editable_user!(socket.assigns.current_user, user_id)
    ]

    {:noreply, assign(socket, assigns)}
  end

  @impl true
  def handle_event("delete-user", %{"id" => user_id}, socket) do
    current_user = socket.assigns.current_user
    to_delete = Accounts.get_editable_user!(current_user, user_id)

    case Accounts.delete_user(current_user, to_delete) do
      {:ok, _deactivated} ->
        assigns = [
          view_to_show: nil,
          users: Accounts.list_users(current_user)
        ]

        {:noreply, socket |> put_flash(:info, "Usuário removido!") |> assign(assigns)}

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
      users: sort_users(socket.assigns.users, col_id, sort)
    ]

    {:noreply, assign(socket, assigns)}
  end

  @impl true
  def handle_event("on-filter", %{"value" => value}, socket) do
    assigns = [
      filter: value,
      users: Accounts.list_users(socket.assigns.current_user, %{q: value})
    ]

    {:noreply, assign(socket, assigns)}
  end

  @impl true
  def handle_event("on-reset-filter", _, socket) do
    assigns = [
      filter: "",
      users: Accounts.list_users(socket.assigns.current_user)
    ]

    {:noreply, assign(socket, assigns)}
  end

  defp sort_users(users, _key, nil), do: users
  defp sort_users(users, key, order), do: Enum.sort_by(users, &Map.get(&1, key), order)

  @impl true
  def handle_info({:user_created, _}, socket) do
    assigns = [
      view_to_show: nil,
      users: Accounts.list_users(socket.assigns.current_user)
    ]

    {:noreply, assign(socket, assigns)}
  end

  @impl true
  def handle_info({:user_updated, _}, socket) do
    assigns = [
      view_to_show: nil,
      users: Accounts.list_users(socket.assigns.current_user)
    ]

    {:noreply, assign(socket, assigns)}
  end
end

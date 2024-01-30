defmodule RefoodWeb.StoragesLive do
  @moduledoc """
  Manages all available storages.
  """
  use RefoodWeb, :live_view

  alias RefoodWeb.StoragesLive.NewStorage

  alias Refood.Inventory.Storages

  @impl true
  def mount(_params, _session, socket) do
    assigns = [
      storages: Storages.list_storages(),
      view_to_show: nil
    ]

    {:ok, assign(socket, assigns)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.header>
      Inventários
      <:actions>
        <.button phx-click="show-new-storage">Novo Inventário</.button>
      </:actions>
    </.header>

    <.live_component
      :if={@view_to_show == :new_storage}
      module={NewStorage}
      id="new-storage"
      on_created={fn storage -> send(self(), {:updated_storage, storage}) end}
      on_cancel={JS.push("hide-all")}
    />

    <.table id="storages" rows={@storages} row_click={&JS.navigate(~p"/storages/#{&1}")}>
      <:col :let={storage} label="Nome"><%= storage.name %></:col>
      <:col :let={storage} label="Criado em">
        <%= NaiveDateTime.to_string(storage.inserted_at) %>
      </:col>
      <:action :let={storage}>
        <div class="sr-only">
          <.link navigate={~p"/storages/#{storage}"}>Ver</.link>
        </div>
      </:action>
    </.table>
    """
  end

  @impl true
  def handle_event("show-new-storage", _unsigned_params, socket) do
    assigns = [
      view_to_show: :new_storage
    ]

    {:noreply, assign(socket, assigns)}
  end

  @impl true
  def handle_event("hide-all", _unsigned_params, socket) do
    assigns = [
      view_to_show: nil
    ]

    {:noreply, assign(socket, assigns)}
  end

  @impl true
  def handle_info({:updated_storage, _}, socket) do
    assigns = [
      storages: Storages.list_storages(),
      view_to_show: nil
    ]

    {:noreply, assign(socket, assigns)}
  end
end

defmodule RefoodWeb.FamiliesLive.SwapForm do
  @moduledoc """
  Component for adding or editing a family's day swap.
  """
  use RefoodWeb, :live_component

  alias Refood.Families

  @impl true
  def update(%{family: _family, swap: swap} = assigns, socket) do
    changeset =
      if swap, do: Families.edit_swap_changeset(swap), else: Families.swap_changeset()

    {:ok, assign(socket, Map.merge(assigns, %{form: to_form(changeset)}))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.modal show id={@id} on_cancel={@on_cancel}>
        <:header>{if @swap, do: "Editar troca", else: "Adicionar troca"}</:header>
        <.simple_form id="swap-details-form" for={@form} phx-submit="save-swap" phx-target={@myself}>
          <.input field={@form[:from]} type="date" label="De" />
          <.input field={@form[:to]} type="date" label="Para" />
          <:actions>
            <.button class="w-full">Guardar</.button>
          </:actions>
        </.simple_form>
      </.modal>
    </div>
    """
  end

  @impl true
  def handle_event("save-swap", %{"swap" => params}, socket) do
    attrs = Map.put(params, "family_id", socket.assigns.family.id)

    result =
      case socket.assigns.swap do
        nil -> Families.add_swap(attrs)
        swap -> Families.update_swap(swap.id, attrs)
      end

    case result do
      {:ok, _swap} ->
        send(self(), {:swap_saved, socket.assigns.family.id})
        send(self(), {:put_flash, [:info, "Sucesso!"]})
        {:noreply, socket}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end
end

defmodule RefoodWeb.ShiftLive.LoanedItems do
  @moduledoc """
  Component for managing loaned items in the shift view.
  """
  use RefoodWeb, :live_component

  alias Refood.Families
  alias RefoodWeb.FamiliesLive.AddLoanedItem

  @impl true
  def update(%{family_id: family_id} = assigns, socket) do
    family = Families.get_family!(family_id)

    updated_assigns =
      Map.merge(assigns, %{
        family: family,
        show_add_form: false
      })

    {:ok, assign(socket, updated_assigns)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.live_component
        :if={@show_add_form}
        module={AddLoanedItem}
        id="add-loaned-item-shift"
        family={@family}
        on_cancel={JS.push("hide-add-form", target: @myself)}
      />

      <.modal :if={!@show_add_form} show id={@id} on_cancel={@on_cancel}>
        <:header>
          Empréstimos - F-{@family.number} {@family.name}
        </:header>
        <div class="py-4">
          <div>
            <div class="border rounded-lg">
              <div
                :if={@family.unreturned_loaned_items == []}
                class="p-4 text-sm text-center text-gray-500"
              >
                Nenhum item emprestado
              </div>
              <div
                :for={item <- Enum.sort_by(@family.unreturned_loaned_items, & &1.loaned_at, :desc)}
                class="p-3 flex justify-between items-center border-b last:border-b-0"
              >
                <div class="flex items-center gap-4">
                  <div>{Calendar.strftime(item.loaned_at, "%Y-%m-%d")}</div>
                  <div>{item.quantity}x {item.name}</div>
                  <div :if={item.returned_at}>
                    Devolvido: {Calendar.strftime(item.returned_at, "%Y-%m-%d")}
                  </div>
                </div>
                <div class="flex flex-row items-center gap-1 justify-center underline text-center">
                  <.icon name="hero-arrow-down-on-square" class="h-4 w-4" />
                  <.link phx-click="mark-as-returned" phx-target={@myself} phx-value-id={item.id}>
                    Marcar devolução
                  </.link>
                </div>
              </div>
            </div>
          </div>
        </div>
        <.button
          class="w-full mt-2 text-sm font-medium"
          phx-click="show-add-form"
          phx-target={@myself}
        >
          + Emprestar item
        </.button>
      </.modal>
    </div>
    """
  end

  @impl true
  def handle_event("show-add-form", _params, socket) do
    {:noreply, assign(socket, show_add_form: true)}
  end

  @impl true
  def handle_event("hide-add-form", _params, socket) do
    {:noreply, assign(socket, show_add_form: false)}
  end

  @impl true
  def handle_event("mark-as-returned", %{"id" => loaned_item_id}, socket) do
    case Families.mark_loaned_item_as_returned(loaned_item_id) do
      {:ok, _loaned_item} ->
        updated_family = Families.get_family!(socket.assigns.family.id)

        send(self(), {:loaned_item_updated, updated_family.id})
        send(self(), {:put_flash, [:info, "Item marcado como devolvido!"]})

        {:noreply,
         socket
         |> assign(family: updated_family)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Erro ao marcar item como devolvido")}
    end
  end
end

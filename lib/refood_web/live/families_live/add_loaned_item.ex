defmodule RefoodWeb.FamiliesLive.AddLoanedItem do
  @moduledoc """
  Component for adding a loaned item to a family.
  """
  use RefoodWeb, :live_component

  alias Refood.Families

  @impl true
  def update(%{family: family} = assigns, socket) do
    changeset =
      Families.change_add_loaned_item(%{
        family_id: family.id,
        name: "",
        quantity: 1,
        loaned_at: DateTime.utc_now()
      })

    updated_assigns =
      Map.merge(assigns, %{
        form: to_form(changeset),
        show_custom_name: false
      })

    {:ok, assign(socket, updated_assigns)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.modal show id={@id} on_cancel={@on_cancel} size={:md}>
        <:header>Emprestar item</:header>
        <:subtitle>
          Registe o que a família leva emprestado, para saber o que falta devolver.
        </:subtitle>
        <:footer>
          <div class="flex justify-end gap-3">
            <.button type="button" variant={:ghost} phx-click={@on_cancel}>Cancelar</.button>
            <.button type="submit" form="add-loaned-item-form">Emprestar item</.button>
          </div>
        </:footer>
        <.record_form
          :let={rf}
          id="add-loaned-item-form"
          for={@form}
          phx-change="validate"
          phx-submit="add-loaned-item"
          phx-target={@myself}
        >
          <.section title="Item">
            <.field
              rf={rf}
              name={:item_type}
              label="Tipo"
              type="select"
              width={:md}
              options={["Tupperware", "Saco", "Outros"]}
              prompt="Selecione um item"
              required
            />
            <.field
              :if={@show_custom_name}
              rf={rf}
              name={:name}
              label="Nome"
              width={:md}
              placeholder="Ex: tabuleiro"
              required
            />
            <.field
              rf={rf}
              name={:quantity}
              label="Quantidade"
              type="number"
              width={:xs}
              min="1"
              step="1"
              required
            />
            <.field rf={rf} name={:loaned_at} label="Emprestado em" type="datetime-local" width={:sm} />
          </.section>
        </.record_form>
      </.modal>
    </div>
    """
  end

  @impl true
  def handle_event("validate", %{"loaned_item" => params}, socket) do
    item_type = params["item_type"]
    show_custom? = item_type == "Outros"

    name = if show_custom?, do: params["name"], else: item_type

    changeset =
      params
      |> Map.put("name", name)
      |> Families.change_add_loaned_item()

    {:noreply,
     assign(socket, form: to_form(changeset, action: :validate), show_custom_name: show_custom?)}
  end

  @impl true
  def handle_event("add-loaned-item", %{"loaned_item" => params}, socket) do
    item_type = params["item_type"]
    name = if item_type == "Outros", do: params["name"], else: item_type

    attrs =
      params
      |> Map.put("family_id", socket.assigns.family.id)
      |> Map.put("name", name)

    case Families.add_loaned_item(attrs) do
      {:ok, loaned_item} ->
        send(self(), {:loaned_item_added, loaned_item.family_id})
        send(self(), {:put_flash, [:info, "Item emprestado!"]})

        {:noreply, socket}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end
end

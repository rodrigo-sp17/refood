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
      <.modal show id={@id} on_cancel={@on_cancel}>
        <:header>Adicionar item emprestado</:header>
        <.simple_form
          id="add-loaned-item-form"
          for={@form}
          phx-change="validate"
          phx-submit="add-loaned-item"
          phx-target={@myself}
        >
          <.input
            field={@form[:item_type]}
            type="select"
            label="Tipo de item"
            options={["Tupperware", "Saco", "Outros"]}
            prompt="Selecione um item"
            required
          />

          <.input
            :if={@show_custom_name}
            field={@form[:name]}
            type="text"
            label="Nome do item"
            placeholder="Digite o nome do item"
            required
          />

          <.input field={@form[:quantity]} type="number" label="Quantidade" min="1" step="1" required />

          <.input field={@form[:loaned_at]} type="datetime-local" label="Emprestado em" />

          <:actions>
            <.button class="w-full">Adicionar</.button>
          </:actions>
        </.simple_form>
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

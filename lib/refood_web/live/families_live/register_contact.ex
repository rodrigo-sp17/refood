defmodule RefoodWeb.FamiliesLive.RegisterContact do
  @moduledoc """
  Registers a new family contact, dismissing alerts if present.
  """
  use RefoodWeb, :live_component

  alias Refood.Families
  alias Refood.Families.Alert

  @impl true
  def update(%{family: family} = assigns, socket) do
    updated_assigns =
      Map.merge(assigns, %{
        form:
          to_form(
            Families.change_register_contact(%{
              last_contacted_at: DateTime.utc_now(),
              notes: family.notes,
              alerts_to_dismiss: Enum.map(family.active_alerts, & &1.type)
            }),
            as: :family
          )
      })

    {:ok, assign(socket, updated_assigns)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.modal show id={@id} on_cancel={@on_cancel}>
        <:header>Registar contacto para {@family.name}</:header>
        <.simple_form
          id="register-contact-form"
          for={@form}
          phx-change="validate"
          phx-target={@myself}
          phx-submit="register-family-contact"
        >
          <.input field={@form[:last_contacted_at]} label="Contactada em" type="datetime-local" />
          <.input field={@form[:notes]} label="Notas" type="textarea" />
          <.input
            field={@form[:alerts_to_dismiss]}
            label="Tipos de alertas a dispensar"
            type="checkgroup"
            multiple={true}
            options={get_options_from_active_alerts(@family.active_alerts)}
          />
          <:actions>
            <.button class="w-full">Registar</.button>
          </:actions>
        </.simple_form>
      </.modal>
    </div>
    """
  end

  defp get_options_from_active_alerts(active_alerts) do
    Enum.map(active_alerts, fn %{type: type} -> {Alert.type_to_name(type), type} end)
  end

  @impl true
  def handle_event("validate", %{"family" => form_attrs}, socket) do
    form =
      to_form(Families.change_register_contact(form_attrs),
        action: :validate,
        as: :family
      )

    {:noreply, assign(socket, form: form)}
  end

  @impl true
  def handle_event("register-family-contact", %{"family" => form_attrs}, socket) do
    with {:ok, socket} <- authorize(socket, [:manager, :admin]) do
      case Families.register_contact(socket.assigns.family, form_attrs) do
        {:ok, updated_family} ->
          send(self(), {:updated_family, updated_family})
          send(self(), {:put_flash, [:info, "Contacto registado!"]})
          {:noreply, socket}

        {:error, %Ecto.Changeset{} = changeset} ->
          {:noreply, assign(socket, form: to_form(changeset, as: :family))}
      end
    end
  end
end

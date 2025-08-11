defmodule RefoodWeb.FamiliesLive.FamilyDetails do
  @moduledoc """
  Shows/edits a family.
  """
  use RefoodWeb, :live_component

  alias Refood.Families

  @impl true
  def update(%{family: family} = assigns, socket) do
    updated_assigns =
      Map.merge(assigns, %{
        form: to_form(Families.change_update_family_details(family, %{})),
        edit: false
      })

    {:ok, assign(socket, updated_assigns)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.modal show id={@id} on_cancel={@on_cancel}>
        <.header>
          Família {if @family.status == :active, do: "F-#{@family.number} - ", else: "de"} {@family.name}
          <:actions>
            <.button
              :if={@current_user.role in [:admin, :manager] && !@edit}
              phx-target={@myself}
              phx-click="edit-family"
            >
              Editar
            </.button>
          </:actions>
        </.header>

        <.simple_form
          id="family-details-form"
          for={@form}
          phx-change="validate"
          phx-target={@myself}
          phx-submit="update-family"
        >
          <.input disabled={!@edit} field={@form[:name]} type="text" label="Nome" />
          <div class="flex gap-4 justify-stretch">
            <div class="w-full">
              <.input
                disabled={!@edit}
                field={@form[:adults]}
                type="number"
                min="0"
                step="1"
                pattern="[0-9]*"
                label="Adultos"
              />
            </div>
            <div class="w-full">
              <.input
                disabled={!@edit}
                field={@form[:children]}
                type="number"
                min="0"
                step="1"
                pattern="[0-9]*"
                label="Crianças"
              />
            </div>
          </div>
          <.input disabled={!@edit} field={@form[:phone_number]} type="tel" label="Telefone" />
          <.input disabled={!@edit} field={@form[:email]} type="email" label="Email" />
          <.inputs_for :let={fa} field={@form[:address]}>
            <.input disabled={!@edit} field={fa[:line_1]} type="text" label="Endereço" />
            <.input disabled={!@edit} field={fa[:line_2]} type="text" label="Complemento" />
            <div class="flex gap-4 justify-stretch">
              <div class="w-full">
                <.input disabled={!@edit} field={fa[:region]} type="text" label="Região" />
              </div>
              <div class="w-full">
                <.input disabled={!@edit} field={fa[:city]} type="text" label="Cidade" />
              </div>
            </div>
          </.inputs_for>
          <.input
            :if={@family.status == :active}
            disabled={!@edit}
            field={@form[:weekdays]}
            type="checkgroup"
            multiple={true}
            label="Dia(s) da semana"
            options={[
              {"Dom", :sunday},
              {"Seg", :monday},
              {"Ter", :tuesday},
              {"Qua", :wednesday},
              {"Qui", :thursday},
              {"Sex", :friday},
              {"Sab", :saturday}
            ]}
          />
          <.input disabled={!@edit} field={@form[:restrictions]} type="textarea" label="Restrições" />
          <.input disabled={!@edit} field={@form[:notes]} type="textarea" label="Notas" />
          <div>
            <.label for="absence-list">Faltas</.label>
            <div id="absence-list">
              <.list :for={absence <- Enum.sort_by(@family.absences, & &1.date)}>
                <:item title={absence.date}>
                  {if absence.warned, do: "Avisou", else: "Não avisou"}
                </:item>
              </.list>
            </div>
          </div>
          <:actions>
            <.button :if={@edit} class="w-full">Salvar</.button>
          </:actions>
        </.simple_form>
      </.modal>
    </div>
    """
  end

  @impl true
  def handle_event("validate", %{"family" => attrs}, socket) do
    assigns = [
      edit: true,
      form: to_form(Families.change_update_family_details(socket.assigns.family, attrs))
    ]

    {:noreply, assign(socket, assigns)}
  end

  @impl true
  def handle_event("edit-family", _, socket) do
    with {:ok, socket} <- authorize(socket, [:manager, :admin]) do
      assigns = [
        edit: true
      ]

      {:noreply, assign(socket, assigns)}
    end
  end

  @impl true
  def handle_event("update-family", %{"family" => family_attrs}, socket) do
    with {:ok, socket} <- authorize(socket, [:manager, :admin]) do
      case Families.update_family_details(socket.assigns.family, family_attrs) do
        {:ok, created_request} ->
          socket.assigns.on_created.(created_request)

          {:noreply,
           socket
           |> put_flash(:info, "Sucesso!")
           |> assign(edit: false)}

        {:error, %Ecto.Changeset{} = changeset} ->
          {:noreply, assign(socket, form: to_form(changeset))}
      end
    end
  end
end

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
      <.confirmation_modal
        show={false}
        id="confirm-exit"
        question="Tem certeza de que deseja sair? Todas as alterações não salvas serão perdidas."
        confirm_text="Sair"
        on_confirm={@on_cancel}
        deny_text="Voltar"
        on_deny={show_modal(@id)}
        on_cancel={show_modal(@id)}
      />

      <.modal
        show
        id={@id}
        edit={authorize_edit(assigns, @edit)}
        target={@myself}
        on_cancel={if @edit, do: show_modal("confirm-exit"), else: @on_cancel}
      >
        <:header>
          Família {if @family.status == :active, do: "F-#{@family.number} - ", else: "de"} {@family.name}
        </:header>
        <.simple_form
          id="family-details-form"
          for={@form}
          phx-change="validate"
          phx-target={@myself}
          phx-submit="update-family"
        >
          <.form_section>Informações gerais</.form_section>
          <div class="flex gap-4 justify-stretch">
            <div class="flex-3/5">
              <.input edit={@edit} field={@form[:name]} type="text" label="Nome" />
            </div>
            <div class="flex-1/5">
              <.input
                edit={@edit}
                field={@form[:adults]}
                type="number"
                min="0"
                step="1"
                pattern="[0-9]*"
                label="Adultos"
              />
            </div>
            <div class="flex-1/5">
              <.input
                edit={@edit}
                field={@form[:children]}
                type="number"
                min="0"
                step="1"
                pattern="[0-9]*"
                label="Crianças"
              />
            </div>
          </div>
          <div class="flex gap-4 justify-stretch">
            <div class="flex-3/5">
              <.input edit={@edit} field={@form[:email]} type="email" label="Email" />
            </div>
            <div class="flex-2/5">
              <.input edit={@edit} field={@form[:phone_number]} type="tel" label="Telefone" />
            </div>
          </div>
          <.form_section class="pt-10">Morada</.form_section>
          <.inputs_for :let={fa} field={@form[:address]}>
            <.input edit={@edit} field={fa[:line_1]} type="text" label="Endereço" />
            <.input edit={@edit} field={fa[:line_2]} type="text" label="Complemento" />
            <div class="flex gap-4 justify-stretch">
              <div class="w-full">
                <.input edit={@edit} field={fa[:region]} type="text" label="Região" />
              </div>
              <div class="w-full">
                <.input edit={@edit} field={fa[:city]} type="text" label="Cidade" />
              </div>
            </div>
          </.inputs_for>
          <.form_section class="pt-10">Distribuição</.form_section>
          <.input
            :if={@family.status == :active}
            edit={@edit}
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
          <.input edit={@edit} field={@form[:restrictions]} type="textarea" label="Restrições" />
          <.input edit={@edit} field={@form[:notes]} type="textarea" label="Notas" />
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

  defp authorize_edit(%{current_user: user}, edit?) do
    if user.role in [:admin, :manager] do
      edit?
    else
      nil
    end
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
  def handle_event("edit", _, socket) do
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

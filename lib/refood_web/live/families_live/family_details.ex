defmodule RefoodWeb.FamiliesLive.FamilyDetails do
  @moduledoc """
  Shows/edits a family.
  """
  use RefoodWeb, :live_component

  alias Refood.Families
  alias RefoodWeb.FamiliesLive.AddLoanedItem

  @impl true
  def update(%{family: family} = assigns, socket) do
    updated_assigns =
      Map.merge(assigns, %{
        view_to_show: nil,
        form:
          to_form(Families.change_update_family_details(family, %{weekdays: family.weekdays})),
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

      <.confirmation_modal
        :if={@view_to_show == :confirm_delete_absence}
        id="confirm-delete-absence"
        type={:delete}
        question={"Tem certeza de que deseja remover a falta de #{@absence.date}?"}
        confirm_text="Remover"
        on_confirm={JS.push("delete-absence", value: %{id: @absence.id}, target: @myself)}
        deny_text="Cancelar"
        on_deny={JS.push("show-view", target: @myself)}
        on_cancel={JS.push("show-view", target: @myself)}
      />

      <.confirmation_modal
        :if={@view_to_show == :confirm_delete_loaned_item}
        id="confirm-delete-loaned-item"
        type={:delete}
        question={"Tem certeza de que deseja remover o item #{@loaned_item.name}?"}
        confirm_text="Remover"
        on_confirm={JS.push("delete-loaned-item", value: %{id: @loaned_item.id}, target: @myself)}
        deny_text="Cancelar"
        on_deny={JS.push("show-view", target: @myself)}
        on_cancel={JS.push("show-view", target: @myself)}
      />

      <.live_component
        :if={@view_to_show == :add_loaned_item}
        module={AddLoanedItem}
        id="add-loaned-item"
        family={@family}
        on_cancel={JS.push("show-view", target: @myself)}
        on_added={fn _item -> send(self(), {:loaned_item_added, @family.id}) end}
      />

      <.modal
        :if={@view_to_show == nil}
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
          <.input
            edit={@edit}
            field={@form[:speaks_portuguese]}
            type="checkbox"
            label="Fala Português?"
          />
          <div class="flex gap-4 justify-stretch">
            <div class="flex-1/2">
              <.input
                edit={@edit}
                field={@form[:help_requested_at]}
                type="datetime-local"
                label="Ajuda pedida em"
              />
            </div>
            <div class="flex-1/2">
              <.input
                edit={@edit}
                field={@form[:last_contacted_at]}
                type="datetime-local"
                label="Último contacto em"
              />
            </div>
          </div>
          <div class="flex gap-4 justify-stretch">
            <div class="flex-1/3">
              <.input edit={@edit} field={@form[:cc]} type="text" label="CC" />
            </div>
            <div class="flex-1/3">
              <.input edit={@edit} field={@form[:nif]} type="text" label="NIF" />
            </div>
            <div class="flex-1/3">
              <.input edit={@edit} field={@form[:niss]} type="text" label="NISS" />
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
            <div class="flex items-center justify-between">
              <.label for="loaned-items-list">Empréstimos</.label>
              <.link
                :if={@current_user.role in [:admin, :manager]}
                phx-click="show-add-loaned-item"
                phx-target={@myself}
                class="text-sm text-black font-medium"
              >
                + Adicionar item
              </.link>
            </div>
            <div id="loaned-items-list" class="mt-2 border rounded-lg">
              <div :if={@family.loaned_items == []} class="p-2 text-sm text-center">
                Nenhum item emprestado
              </div>
              <div
                :for={item <- Enum.sort_by(@family.loaned_items, & &1.loaned_at, {:desc, DateTime})}
                class={"p-2 flex justify-between rounded-lg items-center relative text-sm border-b last:border-b-0 #{if item.returned_at, do: "bg-gray-50 text-gray-500", else: ""}"}
              >
                <div class="flex gap-4">
                  <div>{Calendar.strftime(item.loaned_at, "%Y-%m-%d")}</div>
                  <div>{item.quantity}x {item.name}</div>
                  <div :if={item.returned_at}>
                    Devolvido: {Calendar.strftime(item.returned_at, "%Y-%m-%d")}
                  </div>
                </div>
                <.dropdown
                  :if={@current_user.role in [:admin, :manager]}
                  id={"loaned-item-dropdown-#{item.id}"}
                >
                  <:link
                    :if={!item.returned_at}
                    on_click={
                      JS.push("mark-loaned-item-returned", value: %{id: item.id}, target: @myself)
                    }
                  >
                    Marcar como devolvido
                  </:link>
                  <:link on_click={
                    JS.push("confirm-delete-loaned-item", value: %{id: item.id}, target: @myself)
                  }>
                    <p class="text-red-500">Remover item</p>
                  </:link>
                </.dropdown>
              </div>
            </div>
          </div>
          <div>
            <.label for="absence-list">Faltas</.label>
            <div id="absence-list" class="mt-2 border rounded-lg">
              <div :if={@family.absences == []} class="p-2 text-sm text-center">
                Nenhuma falta registada
              </div>
              <div
                :for={absence <- Enum.sort_by(@family.absences, & &1.date)}
                class="p-2 flex justify-between rounded-lg items-center relative text-sm border-b last:border-b-0"
              >
                <div class="flex gap-5">
                  <div>{absence.date}</div>
                  <div title={absence.date}>
                    {if absence.warned, do: "Avisou", else: "Não avisou"}
                  </div>
                </div>
                <.dropdown id={"absence-dropdown-#{absence.id}"}>
                  <:link
                    :if={!absence.warned}
                    on_click={
                      JS.push("edit-absence", value: %{id: absence.id, warned: true}, target: @myself)
                    }
                  >
                    Marcar como justificada
                  </:link>
                  <:link
                    :if={absence.warned}
                    on_click={
                      JS.push("edit-absence",
                        value: %{id: absence.id, warned: false},
                        target: @myself
                      )
                    }
                  >
                    Marcar como não-justificada
                  </:link>
                  <:link on_click={
                    JS.push("confirm-delete-absence", value: %{id: absence.id}, target: @myself)
                  }>
                    <p class="text-red-500">Remover falta</p>
                  </:link>
                </.dropdown>
              </div>
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
  def handle_event("show-view", _unsigned_params, socket) do
    socket = assign(socket, view_to_show: nil)
    {:noreply, socket}
  end

  @impl true
  def handle_event("validate", %{"family" => attrs}, socket) do
    assigns = [
      edit: true,
      form:
        to_form(Families.change_update_family_details(socket.assigns.family, attrs),
          action: :validate
        )
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
        {:ok, updated_family} ->
          socket.assigns.on_created.(updated_family)

          {:noreply,
           socket
           |> put_flash(:info, "Sucesso!")
           |> assign(edit: false)}

        {:error, %Ecto.Changeset{} = changeset} ->
          {:noreply, assign(socket, form: to_form(changeset))}
      end
    end
  end

  @impl true
  def handle_event("edit-absence", %{"id" => absence_id, "warned" => warned}, socket) do
    with {:ok, socket} <- authorize(socket, [:manager, :admin]) do
      case Families.update_absence(absence_id, %{warned: warned}) do
        {:ok, _absence} ->
          {:noreply,
           socket
           |> put_flash(:info, "Sucesso!")
           |> assign(:family, Families.get_family!(socket.assigns.family.id))}

        {:error, _} ->
          {socket
           |> put_flash(:error, "Falha em editar falta!")}
      end
    end
  end

  @impl true
  def handle_event("confirm-delete-absence", %{"id" => absence_id}, socket) do
    with {:ok, socket} <- authorize(socket, [:manager, :admin]) do
      absence = Enum.find(socket.assigns.family.absences, &(&1.id == absence_id))

      assigns = [
        view_to_show: :confirm_delete_absence,
        absence: absence
      ]

      {:noreply, assign(socket, assigns)}
    end
  end

  @impl true
  def handle_event("delete-absence", %{"id" => absence_id}, socket) do
    with {:ok, socket} <- authorize(socket, [:manager, :admin]) do
      case Families.delete_absence(absence_id) do
        {:ok, _absence} ->
          {:noreply,
           socket
           |> put_flash(:info, "Sucesso!")
           |> assign(view_to_show: nil)
           |> assign(family: Families.get_family!(socket.assigns.family.id))}

        {:error, _} ->
          {socket
           |> put_flash(:error, "Falha em remover falta!")}
      end
    end
  end

  @impl true
  def handle_event("show-add-loaned-item", _params, socket) do
    with {:ok, socket} <- authorize(socket, [:manager, :admin]) do
      {:noreply, assign(socket, view_to_show: :add_loaned_item)}
    end
  end

  @impl true
  def handle_event("mark-loaned-item-returned", %{"id" => loaned_item_id}, socket) do
    with {:ok, socket} <- authorize(socket, [:manager, :admin]) do
      case Families.mark_loaned_item_as_returned(loaned_item_id) do
        {:ok, _loaned_item} ->
          {:noreply,
           socket
           |> put_flash(:info, "Item marcado como devolvido!")
           |> assign(family: Families.get_family!(socket.assigns.family.id))}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Falha em marcar item como devolvido")}
      end
    end
  end

  @impl true
  def handle_event("confirm-delete-loaned-item", %{"id" => loaned_item_id}, socket) do
    with {:ok, socket} <- authorize(socket, [:manager, :admin]) do
      loaned_item = Enum.find(socket.assigns.family.loaned_items, &(&1.id == loaned_item_id))

      assigns = [
        view_to_show: :confirm_delete_loaned_item,
        loaned_item: loaned_item
      ]

      {:noreply, assign(socket, assigns)}
    end
  end

  @impl true
  def handle_event("delete-loaned-item", %{"id" => loaned_item_id}, socket) do
    with {:ok, socket} <- authorize(socket, [:manager, :admin]) do
      case Families.delete_loaned_item(loaned_item_id) do
        {:ok, _loaned_item} ->
          {:noreply,
           socket
           |> put_flash(:info, "Item removido!")
           |> assign(view_to_show: nil)
           |> assign(family: Families.get_family!(socket.assigns.family.id))}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Falha em remover item")}
      end
    end
  end
end

defmodule RefoodWeb.HelpQueueLive.HelpRequestDetails do
  @moduledoc """
  Shows/edits a help request.
  """
  use RefoodWeb, :live_component

  alias Refood.Families.HelpQueue

  @impl true
  def update(%{family: family} = assigns, socket) do
    updated_assigns =
      Map.merge(assigns, %{
        form: to_form(HelpQueue.change_update_help_request(family, %{})),
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
        edit={@edit}
        on_cancel={if @edit, do: show_modal("confirm-exit"), else: @on_cancel}
        target={@myself}
      >
        <:header>
          Pedido de ajuda para {@family.name}
        </:header>

        <.simple_form
          id="help-request-details-form"
          for={@form}
          phx-change="validate"
          phx-target={@myself}
          phx-submit="update-help-request"
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
                <.input edit={@edit} field={fa[:city]} type="text" label="Cidade" value="Porto" />
              </div>
            </div>
          </.inputs_for>
          <.form_section class="pt-10">Distribuição</.form_section>
          <.input edit={@edit} field={@form[:restrictions]} type="textarea" label="Restrições" />
          <.input edit={@edit} field={@form[:notes]} type="textarea" label="Notas" />
          <:actions>
            <.button :if={@edit} class="w-full">Salvar</.button>
          </:actions>
        </.simple_form>
      </.modal>
    </div>
    """
  end

  @impl true
  def handle_event("edit", _, socket) do
    assigns = [
      edit: true,
      form: to_form(HelpQueue.change_update_help_request(socket.assigns.family, %{}))
    ]

    {:noreply, assign(socket, assigns)}
  end

  @impl true
  def handle_event("validate", %{"family" => attrs}, socket) do
    assigns = [
      edit: true,
      form: to_form(HelpQueue.change_update_help_request(socket.assigns.family, attrs))
    ]

    {:noreply, assign(socket, assigns)}
  end

  @impl true
  def handle_event("update-help-request", %{"family" => family_attrs}, socket) do
    case HelpQueue.update_help_request(socket.assigns.family, family_attrs) do
      {:ok, created_request} ->
        socket.assigns.on_created.(created_request)
        {:noreply, put_flash(socket, :info, "Sucesso!")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  def handle_info({:updated_family, _}, socket) do
    assigns = [
      edit: false,
      form: to_form(HelpQueue.change_update_help_request(socket.assigns.family, %{}))
    ]

    {:noreply, assign(socket, assigns)}
  end
end

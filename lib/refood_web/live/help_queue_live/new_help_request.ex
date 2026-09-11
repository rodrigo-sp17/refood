defmodule RefoodWeb.HelpQueueLive.NewHelpRequest do
  @moduledoc """
  Component that adds a new help request to the families list.
  """
  use RefoodWeb, :live_component

  alias Refood.Families.HelpQueue

  @impl true
  def mount(socket) do
    assigns = [
      form: to_form(HelpQueue.change_request_help(HelpQueue.new_request_attrs()))
    ]

    {:ok, assign(socket, assigns)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.modal show id={@id} on_cancel={@on_cancel}>
        <:header>Criar pedido de ajuda</:header>
        <:subtitle>Uma família nova entra na lista de espera.</:subtitle>
        <:footer>
          <div class="flex justify-end gap-3">
            <.button type="button" variant={:ghost} phx-click={@on_cancel}>Cancelar</.button>
            <.button type="submit" form="new-help-request-form">Criar pedido</.button>
          </div>
        </:footer>
        <.record_form
          :let={rf}
          id="new-help-request-form"
          for={@form}
          phx-target={@myself}
          phx-change="validate"
          phx-submit="add-help-request"
        >
          <.section title="Identificação">
            <.field rf={rf} name={:name} label="Nome" required />
            <.field rf={rf} name={:adults} label="Adultos" type="number" width={:xs} min="1" step="1" />
            <.field
              rf={rf}
              name={:children}
              label="Crianças"
              type="number"
              width={:xs}
              min="0"
              step="1"
            />
            <.field
              rf={rf}
              name={:email}
              label="Email"
              type="email"
              width={:md}
              hint="Email ou telefone — pelo menos um é preciso para dar retorno."
            />
            <.field rf={rf} name={:phone_number} label="Telefone" type="tel" width={:sm} />
            <.field rf={rf} name={:speaks_portuguese} label="Fala português" type="checkbox" />
          </.section>

          <.section title="Morada">
            <.inputs_for :let={fa} field={rf.form[:address]}>
              <.field rf={rf} form={fa} name={:line_1} label="Endereço" />
              <.field rf={rf} form={fa} name={:line_2} label="Complemento" />
              <.field rf={rf} form={fa} name={:region} label="Região" width={:md} required />
              <.field rf={rf} form={fa} name={:city} label="Cidade" width={:md} required />
              <.field rf={rf} form={fa} name={:zipcode} label="Código postal" width={:sm} />
            </.inputs_for>
          </.section>

          <.section title="Documentos">
            <.field rf={rf} name={:cc} label="Cartão de cidadão" width={:sm} />
            <.field rf={rf} name={:nif} label="Nº de contribuinte" width={:sm} />
            <.field rf={rf} name={:niss} label="Segurança social" width={:sm} />
          </.section>

          <.section title="Acompanhamento">
            <.field
              rf={rf}
              name={:help_requested_at}
              label="Ajuda pedida em"
              type="datetime-local"
              width={:sm}
            />
            <.field rf={rf} name={:notes} label="Notas" type="textarea" />
          </.section>
        </.record_form>
      </.modal>
    </div>
    """
  end

  @impl true
  def handle_event("validate", %{"family" => help_request_attrs}, socket) do
    form =
      to_form(HelpQueue.change_request_help(help_request_attrs), action: :validate)

    {:noreply, assign(socket, form: form)}
  end

  @impl true
  def handle_event("add-help-request", %{"family" => help_request_attrs}, socket) do
    case HelpQueue.request_help(help_request_attrs) do
      {:ok, created_request} ->
        send(self(), {:help_request_created, created_request})
        send(self(), {:put_flash, [:info, "Pedido de ajuda criado!"]})
        {:noreply, socket}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end
end

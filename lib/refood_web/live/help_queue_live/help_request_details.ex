defmodule RefoodWeb.HelpQueueLive.HelpRequestDetails do
  @moduledoc """
  Shows/edits a help request.
  """
  use RefoodWeb, :live_component

  alias Refood.Families.HelpQueue
  alias Refood.Format

  @impl true
  def update(%{family: family} = assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> assign(:mode, :read)
      |> assign(:form, to_form(HelpQueue.change_update_help_request(family, %{})))

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.confirmation_modal
        show={false}
        id="confirm-exit"
        question="Tem alterações por guardar. Sair sem as guardar?"
        confirm_text="Sair sem guardar"
        on_confirm={@on_cancel}
        deny_text="Continuar a editar"
        on_deny={show_modal(@id)}
        on_cancel={show_modal(@id)}
      />

      <.modal
        show
        id={@id}
        edit={@mode == :edit}
        on_cancel={if dirty?(@form), do: show_modal("confirm-exit"), else: @on_cancel}
        target={@myself}
      >
        <:header>{@family.name}</:header>
        <:subtitle>{request_summary(@family)}</:subtitle>

        <:footer :if={@mode == :edit}>
          <.form_actions form={@form} submit_form="help-request-details-form" target={@myself} />
        </:footer>

        <.record_form
          :let={rf}
          id="help-request-details-form"
          for={@form}
          mode={@mode}
          phx-change="validate"
          phx-target={@myself}
          phx-submit="update-help-request"
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
            <.field rf={rf} name={:email} label="Email" type="email" width={:md} />
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

          <.section title="Distribuição">
            <.field
              rf={rf}
              name={:restrictions}
              label="Restrições"
              type="textarea"
              hint="Alimentos que esta família não pode receber."
            />
            <.field rf={rf} name={:notes} label="Notas" type="textarea" />
          </.section>

          <.section title="Acompanhamento">
            <.field
              rf={rf}
              name={:help_requested_at}
              label="Ajuda pedida em"
              type="datetime-local"
              width={:sm}
            />
            <.field
              rf={rf}
              name={:last_contacted_at}
              label="Último contacto"
              type="datetime-local"
              width={:sm}
            />
          </.section>
        </.record_form>
      </.modal>
    </div>
    """
  end

  defp request_summary(family) do
    [
      "Pedido em #{Format.date(family.help_requested_at)}",
      pluralize(family.adults, "adulto", "adultos"),
      pluralize(family.children, "criança", "crianças")
    ]
    |> Enum.reject(&is_nil/1)
    |> Enum.join(" · ")
  end

  defp pluralize(nil, _singular, _plural), do: nil
  defp pluralize(1, singular, _plural), do: "1 #{singular}"
  defp pluralize(count, _singular, plural), do: "#{count} #{plural}"

  @impl true
  def handle_event("edit", _, socket) do
    {:noreply, assign(socket, mode: :edit)}
  end

  @impl true
  def handle_event("cancel-edit", _, socket) do
    form = to_form(HelpQueue.change_update_help_request(socket.assigns.family, %{}))
    {:noreply, assign(socket, mode: :read, form: form)}
  end

  @impl true
  def handle_event("validate", %{"family" => attrs}, socket) do
    form =
      socket.assigns.family
      |> HelpQueue.change_update_help_request(attrs)
      |> to_form(action: :validate)

    {:noreply, assign(socket, form: form)}
  end

  @impl true
  def handle_event("update-help-request", %{"family" => family_attrs}, socket) do
    case HelpQueue.update_help_request(socket.assigns.family, family_attrs) do
      {:ok, updated_request} ->
        socket.assigns.on_created.(updated_request)

        {:noreply,
         socket
         |> put_flash(:info, "Pedido de ajuda guardado!")
         |> assign(mode: :read)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end
end

defmodule RefoodWeb.FamiliesLive.FamilyDetails do
  @moduledoc """
  Shows/edits a family.
  """
  use RefoodWeb, :live_component

  alias Refood.Families
  alias Refood.Format
  alias RefoodWeb.FamiliesLive.AddLoanedItem
  alias RefoodWeb.FamiliesLive.SwapForm

  @impl true
  def update(%{family: family} = assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> assign(:view_to_show, nil)
      |> assign(:mode, :read)
      |> assign(:form, to_form(Families.change_update_family_details(family, %{})))
      |> assign_new(:tab, fn -> :ficha end)

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

      <.confirmation_modal
        :if={@view_to_show == :confirm_delete_absence}
        id="confirm-delete-absence"
        type={:delete}
        question={"Tem certeza de que deseja remover a falta de #{Format.date(@absence.date)}?"}
        confirm_text="Remover"
        on_confirm={JS.push("delete-absence", value: %{id: @absence.id}, target: @myself)}
        deny_text="Cancelar"
        on_deny={JS.push("show-view", target: @myself)}
        on_cancel={JS.push("show-view", target: @myself)}
      />

      <.confirmation_modal
        :if={@view_to_show == :confirm_delete_swap}
        id="confirm-delete-swap"
        type={:delete}
        question={"Tem certeza de que deseja remover a troca de #{Format.date(@swap.from)} para #{Format.date(@swap.to)}?"}
        confirm_text="Remover"
        on_confirm={JS.push("delete-swap", value: %{id: @swap.id}, target: @myself)}
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

      <.live_component
        :if={@view_to_show in [:add_swap, :edit_swap]}
        module={SwapForm}
        id="swap-form"
        family={@family}
        swap={if @view_to_show == :edit_swap, do: @swap, else: nil}
        on_cancel={JS.push("show-view", target: @myself)}
      />

      <.modal
        :if={@view_to_show == nil}
        show
        id={@id}
        edit={edit_affordance(assigns)}
        target={@myself}
        on_cancel={if dirty?(@form), do: show_modal("confirm-exit"), else: @on_cancel}
      >
        <:header>
          {family_title(@family)}
        </:header>
        <:subtitle>{family_summary(@family)}</:subtitle>

        <:toolbar>
          <nav class="-mb-px flex gap-6" aria-label="Secções da ficha">
            <button
              type="button"
              phx-click="show-tab"
              phx-value-tab="ficha"
              phx-target={@myself}
              aria-current={@tab == :ficha && "page"}
              class={tab_class(@tab == :ficha)}
            >
              Ficha
            </button>
            <button
              type="button"
              phx-click="show-tab"
              phx-value-tab="historico"
              phx-target={@myself}
              disabled={@mode == :edit}
              title={@mode == :edit && "Guarde ou cancele as alterações para ver o histórico"}
              aria-current={@tab == :historico && "page"}
              class={[
                tab_class(@tab == :historico),
                "disabled:cursor-not-allowed disabled:opacity-40"
              ]}
            >
              Histórico
              <span class="ml-1 rounded-3xl bg-zinc-100 px-1.5 py-0.5 text-xs text-zinc-600">
                {history_count(@family)}
              </span>
            </button>
          </nav>
        </:toolbar>

        <:footer :if={@mode == :edit}>
          <.form_actions form={@form} submit_form="family-details-form" target={@myself} />
        </:footer>

        <.record_form
          :let={rf}
          :if={@tab == :ficha}
          id="family-details-form"
          for={@form}
          mode={@mode}
          phx-change="validate"
          phx-target={@myself}
          phx-submit="update-family"
        >
          <.section title="Identificação">
            <.field rf={rf} name={:name} label="Nome" />
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
            <.field rf={rf} name={:cc} label="CC" width={:sm} />
            <.field rf={rf} name={:nif} label="NIF" width={:sm} />
            <.field rf={rf} name={:niss} label="NISS" width={:sm} />
          </.section>

          <.section title="Morada">
            <.inputs_for :let={fa} field={rf.form[:address]}>
              <.field rf={rf} form={fa} name={:line_1} label="Endereço" />
              <.field rf={rf} form={fa} name={:line_2} label="Complemento" />
              <.field rf={rf} form={fa} name={:region} label="Região" width={:md} />
              <.field rf={rf} form={fa} name={:city} label="Cidade" width={:md} />
            </.inputs_for>
          </.section>

          <.section title="Distribuição">
            <.field
              :if={@family.status == :active}
              rf={rf}
              name={:weekdays}
              label="Dias"
              type="weekdays"
              multiple
            />
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

        <div :if={@tab == :historico} class="flex flex-col gap-8">
          <.record_list
            id="loaned-items-list"
            title="Empréstimos"
            items={Enum.sort_by(@family.loaned_items, & &1.loaned_at, {:desc, DateTime})}
            empty_message="Nenhum item emprestado"
          >
            <:action>
              <.button
                :if={@current_user.role in [:admin, :manager]}
                type="button"
                variant={:secondary}
                size={:sm}
                phx-click="show-add-loaned-item"
                phx-target={@myself}
              >
                Emprestar item
              </.button>
            </:action>
            <:item :let={item}>
              <div class={[
                "flex flex-wrap items-baseline gap-x-4",
                item.returned_at && "text-zinc-500"
              ]}>
                <span class="tabular-nums text-zinc-500">{Format.date(item.loaned_at)}</span>
                <span class="font-medium">{item.quantity}x {item.name}</span>
                <span :if={item.returned_at} class="text-zinc-500">
                  Devolvido em {Format.date(item.returned_at)}
                </span>
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
                  <span class="text-rose-600">Remover item</span>
                </:link>
              </.dropdown>
            </:item>
          </.record_list>

          <.record_list
            id="absence-list"
            title="Faltas"
            items={Enum.sort_by(@family.absences, & &1.date, {:desc, Date})}
            empty_message="Nenhuma falta registada"
          >
            <:item :let={absence}>
              <div class="flex flex-wrap items-baseline gap-x-4">
                <span class="tabular-nums text-zinc-500">{Format.date(absence.date)}</span>
                <.badge color={if absence.warned, do: :neutral, else: :warning}>
                  {if absence.warned, do: "Avisou", else: "Não avisou"}
                </.badge>
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
                    JS.push("edit-absence", value: %{id: absence.id, warned: false}, target: @myself)
                  }
                >
                  Marcar como não-justificada
                </:link>
                <:link on_click={
                  JS.push("confirm-delete-absence", value: %{id: absence.id}, target: @myself)
                }>
                  <span class="text-rose-600">Remover falta</span>
                </:link>
              </.dropdown>
            </:item>
          </.record_list>

          <.record_list
            id="swaps-list"
            title="Trocas"
            items={Enum.sort_by(@family.swaps, & &1.to, {:desc, Date})}
            empty_message="Nenhuma troca registada"
          >
            <:action>
              <.button
                :if={@current_user.role in [:admin, :manager]}
                type="button"
                variant={:secondary}
                size={:sm}
                phx-click="show-add-swap"
                phx-target={@myself}
              >
                Adicionar troca
              </.button>
            </:action>
            <:item :let={swap}>
              <div class="flex flex-wrap items-baseline gap-x-2 tabular-nums">
                <span class="text-zinc-500">{Format.date(swap.from)}</span>
                <.icon name="hero-arrow-right-mini" class="h-4 w-4 text-zinc-400" />
                <span class="font-medium">{Format.date(swap.to)}</span>
              </div>
              <.dropdown
                :if={@current_user.role in [:admin, :manager]}
                id={"swap-dropdown-#{swap.id}"}
              >
                <:link on_click={JS.push("show-edit-swap", value: %{id: swap.id}, target: @myself)}>
                  Editar troca
                </:link>
                <:link on_click={
                  JS.push("confirm-delete-swap", value: %{id: swap.id}, target: @myself)
                }>
                  <span class="text-rose-600">Remover troca</span>
                </:link>
              </.dropdown>
            </:item>
          </.record_list>
        </div>
      </.modal>
    </div>
    """
  end

  # nil hides the edit affordance for volunteers; false offers it; true means editing.
  defp edit_affordance(%{current_user: user, mode: mode}) do
    if user.role in [:admin, :manager], do: mode == :edit
  end

  defp family_title(%{status: :active} = family), do: "F-#{family.number} · #{family.name}"
  defp family_title(family), do: family.name

  defp family_summary(family) do
    [
      family_status(family.status),
      pluralize(family.adults, "adulto", "adultos"),
      pluralize(family.children, "criança", "crianças"),
      Format.weekdays(family.weekdays)
    ]
    |> Enum.reject(&is_nil/1)
    |> Enum.join(" · ")
  end

  defp family_status(:active), do: "Ativa"
  defp family_status(:queued), do: "Em lista de espera"
  defp family_status(:paused), do: "Em pausa"
  defp family_status(:finished), do: "Inativa"

  defp pluralize(nil, _singular, _plural), do: nil
  defp pluralize(1, singular, _plural), do: "1 #{singular}"
  defp pluralize(count, _singular, plural), do: "#{count} #{plural}"

  defp history_count(family) do
    length(family.loaned_items) + length(family.absences) + length(family.swaps)
  end

  defp tab_class(active?) do
    [
      "border-b-2 py-3 text-sm font-semibold focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-zinc-900",
      if(active?,
        do: "border-zinc-900 text-zinc-900",
        else: "border-transparent text-zinc-500 hover:border-zinc-300 hover:text-zinc-900"
      )
    ]
  end

  @impl true
  def handle_event("show-view", _unsigned_params, socket) do
    socket = assign(socket, view_to_show: nil)
    {:noreply, socket}
  end

  @impl true
  def handle_event("show-tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, tab: if(tab == "historico", do: :historico, else: :ficha))}
  end

  @impl true
  def handle_event("validate", %{"family" => attrs}, socket) do
    form =
      socket.assigns.family
      |> Families.change_update_family_details(attrs)
      |> to_form(action: :validate)

    {:noreply, assign(socket, form: form)}
  end

  @impl true
  def handle_event("edit", _, socket) do
    with {:ok, socket} <- authorize(socket, [:manager, :admin]) do
      {:noreply, assign(socket, mode: :edit, tab: :ficha)}
    end
  end

  @impl true
  def handle_event("cancel-edit", _, socket) do
    form = to_form(Families.change_update_family_details(socket.assigns.family, %{}))
    {:noreply, assign(socket, mode: :read, form: form)}
  end

  @impl true
  def handle_event("update-family", %{"family" => family_attrs}, socket) do
    with {:ok, socket} <- authorize(socket, [:manager, :admin]) do
      case Families.update_family_details(socket.assigns.family, family_attrs) do
        {:ok, updated_family} ->
          socket.assigns.on_created.(updated_family)

          {:noreply,
           socket
           |> put_flash(:info, "Família guardada!")
           |> assign(mode: :read)}

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
  def handle_event("show-add-swap", _params, socket) do
    with {:ok, socket} <- authorize(socket, [:manager, :admin]) do
      {:noreply, assign(socket, view_to_show: :add_swap)}
    end
  end

  @impl true
  def handle_event("show-edit-swap", %{"id" => swap_id}, socket) do
    with {:ok, socket} <- authorize(socket, [:manager, :admin]) do
      swap = Enum.find(socket.assigns.family.swaps, &(&1.id == swap_id))
      {:noreply, assign(socket, view_to_show: :edit_swap, swap: swap)}
    end
  end

  @impl true
  def handle_event("confirm-delete-swap", %{"id" => swap_id}, socket) do
    with {:ok, socket} <- authorize(socket, [:manager, :admin]) do
      swap = Enum.find(socket.assigns.family.swaps, &(&1.id == swap_id))

      assigns = [
        view_to_show: :confirm_delete_swap,
        swap: swap
      ]

      {:noreply, assign(socket, assigns)}
    end
  end

  @impl true
  def handle_event("delete-swap", %{"id" => swap_id}, socket) do
    with {:ok, socket} <- authorize(socket, [:manager, :admin]) do
      case Families.delete_swap(swap_id) do
        {:ok, _swap} ->
          {:noreply,
           socket
           |> put_flash(:info, "Sucesso!")
           |> assign(view_to_show: nil)
           |> assign(family: Families.get_family!(socket.assigns.family.id))}

        {:error, _} ->
          {socket
           |> put_flash(:error, "Falha em remover troca!")}
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

defmodule RefoodWeb.FamiliesLive.MoveToActive do
  @moduledoc """
  Moves the family on the help request queue to active.
  """
  use RefoodWeb, :html

  attr :id, :string, required: true
  attr :for, :any, required: true
  attr :family, :any, required: true
  attr :on_cancel, JS, default: %JS{}
  attr :target, :any, default: nil

  def form(assigns) do
    ~H"""
    <div>
      <.modal show id={@id} on_cancel={@on_cancel} size={:md}>
        <:header>Mover para ajuda regular</:header>
        <:subtitle>{@family.name}</:subtitle>
        <:footer>
          <div class="flex justify-end gap-3">
            <.button type="button" variant={:ghost} phx-click={@on_cancel}>Cancelar</.button>
            <.button type="submit" form="move-to-active-form">Ativar família</.button>
          </div>
        </:footer>
        <.record_form
          :let={rf}
          id="move-to-active-form"
          for={@for}
          phx-target={@target}
          phx-change="validate-move-to-active"
          phx-submit="move-to-active"
        >
          <.section title="Distribuição">
            <.field
              rf={rf}
              name={:number}
              label="Número"
              type="number"
              width={:xs}
              min="1"
              step="1"
              required
              hint="O código que identifica a família, sem o F."
            />
            <.field rf={rf} name={:weekdays} label="Dias" type="weekdays" multiple required />
          </.section>
        </.record_form>
      </.modal>
    </div>
    """
  end
end

defmodule RefoodWeb.FamiliesLive.MoveToActive do
  @moduledoc """
  Moves the family on the help request queue to active.
  """
  use RefoodWeb, :html

  attr :id, :string, required: true
  attr :for, :any, required: true
  attr :family, :any, required: true
  attr :on_cancel, JS, default: %JS{}
  attr :target, :any

  def form(assigns) do
    ~H"""
    <div>
      <.modal show id={@id} on_cancel={@on_cancel}>
        <.header>
          Mover {@family.name} para ajuda regular
        </.header>
        <.simple_form :let={f} for={@for} phx-target={@target} phx-submit="move-to-active">
          <div class="flex flex-row gap-10">
            <div class="w-30">
              <.input
                field={f[:number]}
                type="number"
                min="0"
                step="1"
                pattern="[0-9]*"
                label="No."
                value={@family.number}
              />
            </div>
            <div class="w-30">
              <.input
                field={f[:weekdays]}
                type="checkgroup"
                multiple={true}
                label="Dia(s) da semana"
                options={[
                  {"Dom", "sunday"},
                  {"Seg", "monday"},
                  {"Ter", "tuesday"},
                  {"Qua", "wednesday"},
                  {"Qui", "thursday"},
                  {"Sex", "friday"},
                  {"Sab", "saturday"}
                ]}
                value={@family.weekdays}
              />
            </div>
          </div>
          <.error :if={@for.action}>
            Oops, algo de errado aconteceu!
          </.error>

          <:actions>
            <.button class="w-full">Ativar</.button>
          </:actions>
        </.simple_form>
      </.modal>
    </div>
    """
  end
end

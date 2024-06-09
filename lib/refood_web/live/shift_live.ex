defmodule RefoodWeb.ShiftLive do
  @moduledoc """
  Handles daily shift summary and shift displays.
  """
  use RefoodWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    assigns = []
    {:ok, assign(socket, assigns)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.header>
      Turno
    </.header>

    <div class="mt-11 flex flex-col gap-8 w-9/12">
      <div class="flex justify-center items-center gap-8">
        <button class="flex items-center rounded-full bg-white group hover:bg-black border border-black p-1">
          <.icon name="hero-chevron-left" class="bg-black group-hover:bg-white" />
        </button>
        <div class="text-3xl font-bold">(Hoje) Quarta-feira, 20 de Junho de 2024</div>
        <button class="flex items-center rounded-full bg-white group hover:bg-black border border-black p-1">
          <.icon name="hero-chevron-right" class="bg-black group-hover:bg-white" />
        </button>
      </div>
      <div class="flex flex-col bg-white rounded-lg divide-y w-full">
        <div class="px-6 py-4">
          <h4 class="text-xl font-medium relative">Familias</h4>
        </div>
        <div class="px-6 flex flex-col divide-y">
          <div class="py-4 flex justify-between items-center">
            <div class="text-xl font-bold basis-1/6">F-9</div>
            <div class="text-lg basis-1/5">Abdul</div>
            <div class="text-lg basis-1/6 flex items-center gap-3">
              <.icon name="hero-users-solid" />2 + 2
            </div>
            <div class="basis-1/5 text-red-500 flex items-center gap-1">
              <.icon name="hero-exclamation-triangle-solid" />Poucos doces
            </div>
            <div class="basis-1/4 flex items-center gap-6">
              <.link class="underline underline-offset-4"> Trocar dia</.link>
              <.button class="flex items-center gap-1 rounded-3xl bg-transparent text-black border border-black px-6">
                <.icon name="hero-exclamation-circle" /> Faltou
              </.button>
            </div>
          </div>
          <div class="py-4 flex justify-between items-center">
            <div class="text-xl font-bold basis-1/6">F-12</div>
            <div class="text-lg basis-1/5">Vania</div>
            <div class="text-lg basis-1/6 flex items-center gap-3">
              <.icon name="hero-users-solid" />2 + 2
            </div>
            <div class="basis-1/5 flex items-center gap-1">-</div>
            <div class="basis-1/4 flex items-center gap-6">
              <.link class="underline underline-offset-4"> Trocar dia</.link>
              <.button class="flex items-center gap-1 rounded-3xl bg-transparent text-black border border-black px-6">
                <.icon name="hero-exclamation-circle" /> Faltou
              </.button>
            </div>
          </div>
          <div class="py-4 flex justify-between items-center">
            <div class="text-xl font-bold basis-1/6">F-22</div>
            <div class="text-lg basis-1/5">Santiago</div>
            <div class="text-lg basis-1/6 flex items-center gap-3">
              <.icon name="hero-users-solid" />1
            </div>
            <div class="basis-1/5 flex items-center gap-1">-</div>
            <div class="basis-1/4 flex items-center gap-6">
              <.link class="underline underline-offset-4">
                Trocar dia
              </.link>
              <.button class="flex items-center gap-1 rounded-3xl bg-transparent text-black border border-black px-6">
                <.icon name="hero-exclamation-circle" /> Faltou
              </.button>
            </div>
          </div>
        </div>
      </div>
      <.button class="py-5">Registrar pedido de ajuda</.button>
    </div>
    """
  end
end

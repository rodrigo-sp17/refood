defmodule RefoodWeb.ShiftLive do
  @moduledoc """
  Handles daily shift summary and shift displays.
  """
  use RefoodWeb, :live_view

  alias Refood.Families

  @impl true
  def mount(_params, _session, socket) do
    date = Date.utc_today()

    assigns = [
      date: date,
      families: Families.list_families_by_date(date),
      selected_family: nil,
      view_to_show: nil
    ]

    {:ok, assign(socket, assigns)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.header>
      Turno
    </.header>

    <.modal
      :if={@view_to_show == :add_absence}
      id="add-absence"
      show
      on_cancel={JS.push("cancel-modal")}
    >
      <div class="flex flex-col gap-10">
        <h2 class="text-2xl text-center">A família avisou com antecedência sobre a falta?</h2>
        <div class="flex justify-center gap-8 h-12">
          <button
            phx-click="add-absence"
            phx-value-warned="true"
            class="basis-1/3 rounded-3xl bg-transparent text-black hover:bg-black hover:text-white border border-black px-6"
          >
            Avisou
          </button>
          <button
            phx-click="add-absence"
            phx-value-warned="false"
            class="basis-1/3 rounded-3xl bg-red-500 text-white hover:bg-transparent hover:text-red-500 border border-red-500 px-6"
          >
            Não avisou
          </button>
        </div>
      </div>
    </.modal>

    <.modal :if={@view_to_show == :add_swap} id="add-swap" show on_cancel={JS.push("cancel-modal")}>
      <div class="flex flex-col gap-10">
        <h2 class="text-2xl text-center">Para qual dia deseja trocar?</h2>
        <.simple_form :let={f} for={@changeset} phx-submit="add-swap">
          <.input type="date" field={f[:to]} />
          <.error :if={@changeset.action}>
            Oops, algo de errado aconteceu!
          </.error>

          <:actions>
            <.button>Trocar</.button>
          </:actions>
        </.simple_form>
      </div>
    </.modal>

    <div class="mt-11 flex flex-col gap-8 w-9/12">
      <div class="flex justify-center items-center gap-8">
        <button
          phx-click="prev-date"
          class="flex items-center rounded-full bg-white group hover:bg-black border border-black p-1"
        >
          <.icon name="hero-chevron-left" class="bg-black group-hover:bg-white" />
        </button>
        <div class="basis-7/12 text-3xl text-center font-bold">
          {if @date == Date.utc_today(), do: "(Hoje)"} {"#{weekday_name(Date.day_of_week(@date))}, #{@date.day} de #{month_name(@date.month)} de #{@date.year}"}
        </div>
        <button
          phx-click="next-date"
          class="flex items-center rounded-full bg-white group hover:bg-black border border-black p-1"
        >
          <.icon name="hero-chevron-right" class="bg-black group-hover:bg-white" />
        </button>
      </div>
      <div class="flex flex-col bg-white rounded-lg divide-y w-full">
        <div class="px-6 py-4">
          <h4 class="text-xl font-medium relative">Famílias</h4>
        </div>
        <div class="px-6 flex flex-col divide-y">
          <div :if={@families == []} class="h-16 flex justify-center items-center">
            Nenhuma família para o dia.
          </div>
          <div :for={family <- @families} class="py-4 flex justify-between items-center">
            <div class="text-xl font-bold w-24">F-{family.number}</div>
            <div class="text-lg basis-1/6">{family.name}</div>
            <div class="text-lg basis-1/6 flex items-center gap-3">
              <.icon name="hero-users-solid" />{family.adults} + {family.children}
            </div>
            <div class="basis-1/5 flex items-center gap-1">
              <%= if family.restrictions do %>
                <.icon name="hero-exclamation-triangle-solid text-red-500" />
                <p class="text-red-500">{family.restrictions}</p>
              <% else %>
                -
              <% end %>
            </div>
            <div class="basis-1/4 flex justify-end items-center gap-6">
              <.link
                :if={
                  family.absences == [] && Enum.empty?(family.swaps) &&
                    Date.compare(@date, Date.utc_today()) in [:gt, :eq]
                }
                phx-click="show-swap"
                phx-value-family_id={family.id}
                class="underline underline-offset-4"
              >
                Trocar dia
              </.link>
              <div
                :if={!Enum.empty?(family.swaps)}
                class="w-40 px-10 py-2 border border-yellow-600 text-yellow-600 text-center font-bold"
              >
                Troca
              </div>
              <.button
                :if={family.absences == []}
                phx-click="show-absence"
                phx-value-family_id={family.id}
                class="flex items-center gap-1 rounded-3xl bg-transparent text-black border border-black px-6"
              >
                Marcar falta
              </.button>
              <div :for={absence <- family.absences}>
                <div
                  :if={absence.warned}
                  class="w-40 px-10 py-2 border border-yellow-600 text-yellow-600 text-center font-bold"
                >
                  Avisou
                </div>
                <div
                  :if={!absence.warned}
                  class="w-40 px-10 py-2 border border-red-500 text-red-500 text-center font-bold"
                >
                  Faltou
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
      <.button class="py-5">Novo pedido de ajuda</.button>
    </div>
    """
  end

  @impl true
  def handle_event("prev-date", _, socket) do
    prev_date = Timex.shift(socket.assigns.date, days: -1)

    assigns = [
      date: prev_date,
      families: Families.list_families_by_date(prev_date)
    ]

    {:noreply, assign(socket, assigns)}
  end

  @impl true
  def handle_event("next-date", _, socket) do
    next_date = Timex.shift(socket.assigns.date, days: 1)

    assigns = [
      date: next_date,
      families: Families.list_families_by_date(next_date)
    ]

    {:noreply, assign(socket, assigns)}
  end

  @impl true
  def handle_event("show-absence", %{"family_id" => family_id}, socket) do
    assigns = [selected_family: family_id, view_to_show: :add_absence]
    {:noreply, assign(socket, assigns)}
  end

  @impl true
  def handle_event("add-absence", %{"warned" => warned?}, socket) do
    %{selected_family: family_id, date: date} = socket.assigns

    base_assigns = [
      selected_family: nil,
      view_to_show: nil
    ]

    case Families.add_absence(%{family_id: family_id, warned: warned?, date: date}) do
      {:ok, _} ->
        assigns =
          base_assigns ++ [families: Families.list_families_by_date(date)]

        {:noreply, socket |> assign(assigns) |> put_flash(:info, "Falta registrada!")}

      {:error, changeset} ->
        assigns = base_assigns ++ [changeset: changeset]

        {:noreply, assign(socket, assigns)}
    end
  end

  @impl true
  def handle_event("show-swap", %{"family_id" => family_id}, socket) do
    assigns = [
      selected_family: family_id,
      view_to_show: :add_swap,
      changeset: Families.swap_changeset()
    ]

    {:noreply, assign(socket, assigns)}
  end

  @impl true
  def handle_event("add-swap", %{"swap" => attrs}, socket) do
    %{selected_family: family_id, date: date} = socket.assigns

    final_attrs = Map.merge(attrs, %{"family_id" => family_id, "from" => date})

    case Families.add_swap(final_attrs) do
      {:ok, _swap} ->
        assigns = [
          view_to_show: nil,
          selected_family: nil,
          families: Families.list_families_by_date(date)
        ]

        {:noreply, socket |> assign(assigns) |> put_flash(:info, "Troca efetuada!")}

      {:error, changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  @impl true
  def handle_event("cancel-modal", _, socket) do
    assigns = [selected_family: nil, view_to_show: nil]
    {:noreply, assign(socket, assigns)}
  end

  defp weekday_name(1), do: "Segunda-feira"
  defp weekday_name(2), do: "Terça-feira"
  defp weekday_name(3), do: "Quarta-feira"
  defp weekday_name(4), do: "Quinta-feira"
  defp weekday_name(5), do: "Sexta-feira"
  defp weekday_name(6), do: "Sábado"
  defp weekday_name(7), do: "Domingo"

  defp month_name(1), do: "Janeiro"
  defp month_name(2), do: "Fevereiro"
  defp month_name(3), do: "Março"
  defp month_name(4), do: "Abril"
  defp month_name(5), do: "Maio"
  defp month_name(6), do: "Junho"
  defp month_name(7), do: "Julho"
  defp month_name(8), do: "Agosto"
  defp month_name(9), do: "Setembro"
  defp month_name(10), do: "Outubro"
  defp month_name(11), do: "Novembro"
  defp month_name(12), do: "Dezembro"
end

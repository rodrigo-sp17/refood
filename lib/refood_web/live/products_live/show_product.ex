defmodule RefoodWeb.ProductsLive.ShowProduct do
  @moduledoc """
  Shows a product details.
  """
  use RefoodWeb, :html

  attr :id, :string
  attr :show, :any
  attr :product, :map
  attr :on_cancel, :any

  def render(assigns) do
    ~H"""
    <div>
      <RefoodWeb.StorageLive.ProductPickerComponent.search_modal show id={@id} on_cancel={@on_cancel}>
        <.header>
          Produto {@product.id}
          <:actions></:actions>
        </.header>

        <.list>
          <:item title="Nome">{@product.name}</:item>
          <:item title="Inserido em">{NaiveDateTime.to_string(@product.inserted_at)}</:item>
          <:item title="Atualizado em">{NaiveDateTime.to_string(@product.updated_at)}</:item>
        </.list>
      </RefoodWeb.StorageLive.ProductPickerComponent.search_modal>
    </div>
    """
  end
end

defmodule RefoodWeb.StorageHTML do
  use RefoodWeb, :html

  alias Ecto.Changeset

  embed_templates "storage_html/*"
  embed_templates "storage_item_html/*"

  @doc """
  Renders a storage form.
  """
  attr :changeset, Changeset, required: true
  attr :action, :string, required: true

  def storage_form(assigns)

  @doc """
  Renders a add storage item form.
  """
  attr :storage, Refood.Inventory.Storage, required: true
  attr :changeset, Changeset, required: true
  attr :action, :string, required: true
  def add_item_form(assigns)
end

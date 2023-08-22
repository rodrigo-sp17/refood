defmodule Refood.Inventory.ProductTest do
  use Refood.DataCase

  alias Refood.Inventory.Product

  describe "register" do
    test "errors when invalid attrs" do
      attrs = %{}

      assert {:error, _} = Product.register(attrs)
    end

    test "registers when valid attrs" do
      attrs = %{name: "saco 100L"}

      assert {:ok, %{name: "SACO 100L", inserted_at: _}} = Product.register(attrs)
    end

    test "errors when duplicated names" do
      attrs = %{name: "laranja KG"}

      assert {:ok, _} = Product.register(attrs)
      assert {:error, _} = Product.register(attrs)
    end
  end
end

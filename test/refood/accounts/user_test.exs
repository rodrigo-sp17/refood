defmodule Refood.Accounts.UserTest do
  use Refood.DataCase, async: true

  alias Refood.Accounts.User

  describe "admin_registration_changeset/1" do
    test "creates an admin" do
      attrs = %{
        name: "Jim Doe",
        email: "jim.doe@mail.com",
        password: "12345678900000"
      }

      assert %{valid?: true} = changeset = User.admin_registration_changeset(attrs)

      user = apply_action!(changeset, :insert)

      assert user.confirmed_at
      assert user.role == :admin
      assert user.email == attrs.email
      assert user.hashed_password
    end

    test "error if invalid changes" do
      attrs = %{
        name: "Jim Doe",
        email: "jim.doe@mail.com"
      }

      assert %{valid?: false} = changeset = User.admin_registration_changeset(attrs)

      assert %{password: _} = errors_on(changeset)
    end
  end
end

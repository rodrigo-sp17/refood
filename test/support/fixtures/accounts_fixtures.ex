defmodule Refood.AccountsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Refood.Accounts` context.
  """

  alias Refood.Repo

  def unique_user_email, do: "user#{System.unique_integer()}@example.com"
  def valid_user_password, do: "hello world!"

  def valid_user_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      name: "John Doe",
      role: :manager,
      email: unique_user_email(),
      password: valid_user_password()
    })
  end

  def user_fixture(attrs \\ %{}) do
    %Refood.Accounts.User{}
    |> Refood.Accounts.User.registration_changeset(valid_user_attributes(attrs))
    |> Repo.insert!()
  end

  def extract_user_token(fun) do
    {:ok, captured_email} = fun.(&"[TOKEN]#{&1}[TOKEN]")
    [_, token | _] = String.split(captured_email.text_body, "[TOKEN]")
    token
  end
end

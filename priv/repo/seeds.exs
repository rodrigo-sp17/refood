# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     Refood.Repo.insert!(%Refood.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias Refood.Families.Family
alias Refood.Repo

if Mix.env() == :dev do
  [
    %{
      number: 9,
      name: "Abdul",
      adults: 2,
      children: 2,
      restrictions: "- doces",
      weekdays: [:wednesday, :friday]
    },
    %{
      number: 12,
      name: "Vania",
      adults: 2,
      children: 2,
      restrictions: nil,
      weekdays: [:monday, :wednesday]
    },
    %{
      number: 22,
      name: "Santiago",
      adults: 2,
      children: 2,
      restrictions: nil,
      weekdays: [:wednesday, :saturday]
    },
    %{
      number: 35,
      name: "Marlene",
      adults: 1,
      children: 0,
      restrictions: nil,
      weekdays: [:wednesday, :friday]
    }
  ]
  |> Enum.map(&(Family.changeset(&1) |> Repo.insert!()))
end

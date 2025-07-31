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
alias Refood.Families.HelpQueue
alias Refood.Repo

if Mix.env() == :dev do
  [
    %{
      number: 9,
      name: "Joao Silva",
      adults: 2,
      children: 2,
      restrictions: "- doces",
      phone_number: "+351913002777",
      status: :active,
      address: %{region: "Bonfim", city: "Porto"},
      weekdays: [:wednesday, :friday]
    },
    %{
      number: 12,
      name: "Maria Almeida",
      adults: 2,
      children: 2,
      restrictions: nil,
      email: "maria.almeida@hotmail.com",
      phone_number: "351123456789",
      status: :active,
      address: %{region: "Bonfim", city: "Porto"},
      weekdays: [:monday, :wednesday]
    },
    %{
      number: nil,
      name: "Marlene",
      adults: 1,
      children: 0,
      restrictions: nil,
      status: :finished,
      address: %{region: "Bonfim", city: "Porto"},
      weekdays: [:wednesday, :friday]
    }
  ]
  |> Enum.map(&(Family.changeset(&1) |> Repo.insert!()))

  [
    %{
      name: "Santiago Oliveira",
      adults: 2,
      children: 2,
      restrictions: nil,
      status: :queued,
      email: "santiago.oliveira@hotmail.com",
      address: %{region: "Bonfim", city: "Porto"},
      queue_positon: 1
    }
  ]
  |> Enum.map(&HelpQueue.request_help/1)
end

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

  _wednesday_families =
    [
      %{
        number: 21,
        name: "Ana Costa",
        adults: 3,
        children: 1,
        restrictions: nil,
        phone_number: "+351912345001",
        status: :active,
        address: %{region: "Cedofeita", city: "Porto"},
        weekdays: [:wednesday]
      },
      %{
        number: 22,
        name: "Carlos Fernandes",
        adults: 2,
        children: 3,
        restrictions: "- glúten",
        phone_number: "+351912345002",
        status: :active,
        address: %{region: "Campanhã", city: "Porto"},
        weekdays: [:wednesday]
      },
      %{
        number: 23,
        name: "Filipa Rodrigues",
        adults: 1,
        children: 2,
        restrictions: nil,
        email: "filipa.r@gmail.com",
        phone_number: "+351912345003",
        status: :active,
        address: %{region: "Paranhos", city: "Porto"},
        weekdays: [:wednesday]
      },
      %{
        number: 24,
        name: "Rui Santos",
        adults: 4,
        children: 0,
        restrictions: "- lactose",
        phone_number: "+351912345004",
        status: :active,
        address: %{region: "Bonfim", city: "Porto"},
        weekdays: [:wednesday]
      },
      %{
        number: 25,
        name: "Beatriz Lopes",
        adults: 2,
        children: 2,
        restrictions: nil,
        phone_number: "+351912345005",
        status: :active,
        address: %{region: "Aldoar", city: "Porto"},
        weekdays: [:wednesday]
      },
      %{
        number: 26,
        name: "Nuno Pereira",
        adults: 1,
        children: 0,
        restrictions: nil,
        email: "nuno.pereira@hotmail.com",
        phone_number: "+351912345006",
        status: :active,
        address: %{region: "Ramalde", city: "Porto"},
        weekdays: [:wednesday]
      },
      %{
        number: 27,
        name: "Susana Carvalho",
        adults: 2,
        children: 4,
        restrictions: "- frutos secos",
        phone_number: "+351912345007",
        status: :active,
        address: %{region: "Cedofeita", city: "Porto"},
        weekdays: [:wednesday]
      },
      %{
        number: 28,
        name: "Tiago Martins",
        adults: 3,
        children: 1,
        restrictions: nil,
        phone_number: "+351912345008",
        status: :active,
        address: %{region: "Paranhos", city: "Porto"},
        weekdays: [:wednesday]
      },
      %{
        number: 29,
        name: "Luísa Gonçalves",
        adults: 1,
        children: 3,
        restrictions: nil,
        email: "luisa.g@gmail.com",
        phone_number: "+351912345009",
        status: :active,
        address: %{region: "Campanhã", city: "Porto"},
        weekdays: [:wednesday]
      },
      %{
        number: 30,
        name: "Paulo Ferreira",
        adults: 2,
        children: 1,
        restrictions: "- soja",
        phone_number: "+351912345010",
        status: :active,
        address: %{region: "Bonfim", city: "Porto"},
        weekdays: [:wednesday]
      },
      %{
        number: 31,
        name: "Inês Mendes",
        adults: 3,
        children: 2,
        restrictions: nil,
        phone_number: "+351912345011",
        status: :active,
        address: %{region: "Aldoar", city: "Porto"},
        weekdays: [:wednesday]
      },
      %{
        number: 32,
        name: "Diogo Sousa",
        adults: 1,
        children: 1,
        restrictions: nil,
        email: "diogo.s@outlook.com",
        phone_number: "+351912345012",
        status: :active,
        address: %{region: "Ramalde", city: "Porto"},
        weekdays: [:wednesday]
      },
      %{
        number: 33,
        name: "Catarina Lima",
        adults: 2,
        children: 3,
        restrictions: "- carne de porco",
        phone_number: "+351912345013",
        status: :active,
        address: %{region: "Cedofeita", city: "Porto"},
        weekdays: [:wednesday]
      },
      %{
        number: 34,
        name: "André Ribeiro",
        adults: 4,
        children: 2,
        restrictions: nil,
        phone_number: "+351912345014",
        status: :active,
        address: %{region: "Paranhos", city: "Porto"},
        weekdays: [:wednesday]
      },
      %{
        number: 35,
        name: "Marta Azevedo",
        adults: 2,
        children: 0,
        restrictions: nil,
        email: "marta.az@gmail.com",
        phone_number: "+351912345015",
        status: :active,
        address: %{region: "Campanhã", city: "Porto"},
        weekdays: [:wednesday]
      },
      %{
        number: 36,
        name: "Ricardo Pinto",
        adults: 3,
        children: 3,
        restrictions: "- marisco",
        phone_number: "+351912345016",
        status: :active,
        address: %{region: "Bonfim", city: "Porto"},
        weekdays: [:wednesday]
      },
      %{
        number: 37,
        name: "Joana Cunha",
        adults: 1,
        children: 2,
        restrictions: nil,
        phone_number: "+351912345017",
        status: :active,
        address: %{region: "Aldoar", city: "Porto"},
        weekdays: [:wednesday]
      },
      %{
        number: 38,
        name: "Miguel Teixeira",
        adults: 2,
        children: 1,
        restrictions: nil,
        email: "miguel.t@hotmail.com",
        phone_number: "+351912345018",
        status: :active,
        address: %{region: "Ramalde", city: "Porto"},
        weekdays: [:wednesday]
      },
      %{
        number: 39,
        name: "Vera Nunes",
        adults: 3,
        children: 2,
        restrictions: "- lactose, glúten",
        phone_number: "+351912345019",
        status: :active,
        address: %{region: "Cedofeita", city: "Porto"},
        weekdays: [:wednesday]
      },
      %{
        number: 40,
        name: "Bruno Macedo",
        adults: 2,
        children: 4,
        restrictions: nil,
        phone_number: "+351912345020",
        status: :active,
        address: %{region: "Paranhos", city: "Porto"},
        weekdays: [:wednesday]
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

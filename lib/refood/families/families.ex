defmodule Refood.Families do
  @moduledoc """
  Manages families and their frequencies.
  """
  import Ecto.Query

  alias Refood.Families.Family
  alias Refood.Repo

  def list_families_by_date(%Date{} = date) do
    weekday = Family.weekday_from_date(date)

    from(f in Family, where: ^weekday in f.weekdays, order_by: f.number)
    |> Repo.all()
  end
end

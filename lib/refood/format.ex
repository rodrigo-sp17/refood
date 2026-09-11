defmodule Refood.Format do
  @moduledoc """
  User-facing formatting of dates, times and weekdays.

  The app renders dates in four different formats today (`%d/%m/%Y`,
  `%d/%m/%Y %H:%M:%S`, `%Y-%m-%d`, and bare `Date.to_string/1` leaking ISO into
  Portuguese prose). Everything user-facing goes through here instead, so
  "15/08/2026" means the same thing on every screen.

  Portuguese convention throughout: day before month, 24-hour clock, week
  starting on Monday.
  """

  @weekday_order [:monday, :tuesday, :wednesday, :thursday, :friday, :saturday, :sunday]

  @short_labels %{
    monday: "Seg",
    tuesday: "Ter",
    wednesday: "Qua",
    thursday: "Qui",
    friday: "Sex",
    saturday: "Sáb",
    sunday: "Dom"
  }

  @long_labels %{
    monday: "Segunda-feira",
    tuesday: "Terça-feira",
    wednesday: "Quarta-feira",
    thursday: "Quinta-feira",
    friday: "Sexta-feira",
    saturday: "Sábado",
    sunday: "Domingo"
  }

  @months ~w(Janeiro Fevereiro Março Abril Maio Junho Julho Agosto Setembro Outubro Novembro Dezembro)

  @doc """
  A calendar date: `15/08/2026`. Accepts dates, datetimes, or nil.
  """
  def date(nil), do: nil
  def date(%Date{} = date), do: Calendar.strftime(date, "%d/%m/%Y")
  def date(%DateTime{} = datetime), do: datetime |> DateTime.to_date() |> date()
  def date(%NaiveDateTime{} = naive), do: naive |> NaiveDateTime.to_date() |> date()

  @doc """
  A date with the time of day: `15/08/2026 14:30`.
  """
  def datetime(nil), do: nil
  def datetime(%DateTime{} = datetime), do: Calendar.strftime(datetime, "%d/%m/%Y %H:%M")
  def datetime(%NaiveDateTime{} = naive), do: Calendar.strftime(naive, "%d/%m/%Y %H:%M")
  def datetime(%Date{} = date), do: date(date)

  @doc """
  A date written out: `Sexta-feira, 15 de Agosto de 2026`.
  """
  def long_date(nil), do: nil

  def long_date(%Date{} = date) do
    weekday = date |> weekday_from_date() |> long_weekday()
    month = Enum.at(@months, date.month - 1)
    "#{weekday}, #{date.day} de #{month} de #{date.year}"
  end

  @doc """
  A compact date with its weekday: `Sex, 15 Ago`.
  """
  def short_date(nil), do: nil

  def short_date(%Date{} = date) do
    weekday = date |> weekday_from_date() |> short_weekday()
    month = @months |> Enum.at(date.month - 1) |> String.slice(0, 3)
    "#{weekday}, #{date.day} #{month}"
  end

  @doc """
  Three-letter weekday label: `Qua`.
  """
  def short_weekday(day), do: Map.fetch!(@short_labels, to_weekday(day))

  @doc """
  Full weekday name: `Quarta-feira`.
  """
  def long_weekday(day), do: Map.fetch!(@long_labels, to_weekday(day))

  @doc """
  A family's distribution days in week order: `Qua, Sex`. Returns nil when empty,
  so callers can fall back to a placeholder.
  """
  def weekdays(nil), do: nil
  def weekdays([]), do: nil

  def weekdays(days) do
    days
    |> Enum.map(&to_weekday/1)
    |> sort_weekdays()
    |> Enum.map_join(", ", &short_weekday/1)
  end

  @doc """
  Weekday options for pickers, Monday first: `[{"Seg", :monday}, ...]`.
  """
  def weekday_options, do: Enum.map(@weekday_order, &{short_weekday(&1), &1})

  @doc """
  Sorts weekdays into week order regardless of how they were stored.
  """
  def sort_weekdays(days) do
    Enum.sort_by(days, fn day -> Enum.find_index(@weekday_order, &(&1 == to_weekday(day))) end)
  end

  defp weekday_from_date(%Date{} = date), do: Enum.at(@weekday_order, Date.day_of_week(date) - 1)

  defp to_weekday(day) when is_atom(day), do: day
  defp to_weekday(day) when is_binary(day), do: String.to_existing_atom(day)
end

defmodule HeidyApi.Planner.Schedule do
  @moduledoc "The computed weekly grid of a semester, built from meetings."

  alias HeidyApi.Planner.{Enrollment, Semester}

  @days ~w(monday tuesday wednesday thursday friday saturday sunday)a

  @type slot :: %{
          enrollment_id: String.t(),
          title: String.t() | nil,
          color: String.t() | nil,
          starts_at: Time.t(),
          ends_at: Time.t(),
          location: String.t() | nil
        }

  @type t :: %{semester_id: String.t(), days: %{atom() => [slot()]}}

  @spec week([Enrollment.t()], Semester.t()) :: t()
  def week(enrollments, %Semester{id: semester_id}) do
    slots =
      for enrollment <- enrollments, meeting <- enrollment.meetings do
        {Enum.at(@days, meeting.day_of_week - 1),
         %{
           enrollment_id: enrollment.id,
           title: enrollment.title,
           color: enrollment.color,
           starts_at: meeting.starts_at,
           ends_at: meeting.ends_at,
           location: meeting.location
         }}
      end

    days =
      Map.new(@days, fn day ->
        day_slots =
          slots
          |> Enum.filter(fn {slot_day, _slot} -> slot_day == day end)
          |> Enum.map(&elem(&1, 1))
          |> Enum.sort_by(& &1.starts_at)

        {day, day_slots}
      end)

    %{semester_id: semester_id, days: days}
  end
end

defmodule HeidyApiWeb.Serializer do
  @moduledoc """
  Maps domain structs to their public JSON shapes. The only place where
  wire formatting (e.g. wall-clock times as `HH:MM`) happens.
  """

  alias HeidyApi.Accounts.User
  alias HeidyApi.Catalog.{Course, Discipline, Unit, University}
  alias HeidyApi.Credentials.{Blob, LoginKey}
  alias HeidyApi.Planner.{Absence, AttendanceSummary, Enrollment, Grade, GradeSummary}
  alias HeidyApi.Planner.{Meeting, Semester, Task}
  alias HeidyApi.Usp.SyncRun

  @spec render(term()) :: term()
  def render(list) when is_list(list), do: Enum.map(list, &render/1)

  def render(%User{} = user) do
    Map.take(user, [:id, :usp_username, :name, :email, :course_id])
  end

  def render(%Semester{} = semester) do
    Map.take(semester, [:id, :label, :start_date, :end_date, :active, :source])
  end

  def render(%Enrollment{} = enrollment) do
    enrollment
    |> Map.take([
      :id,
      :semester_id,
      :discipline_id,
      :title,
      :professor,
      :credits,
      :color,
      :absence_limit,
      :source,
      :external_ref
    ])
    |> Map.put(:meetings, render(enrollment.meetings))
  end

  def render(%Meeting{} = meeting) do
    meeting
    |> Map.take([:id, :enrollment_id, :day_of_week, :location])
    |> Map.put(:starts_at, hhmm(meeting.starts_at))
    |> Map.put(:ends_at, hhmm(meeting.ends_at))
  end

  def render(%Task{} = task) do
    Map.take(task, [
      :id,
      :enrollment_id,
      :title,
      :notes,
      :kind,
      :status,
      :priority,
      :due_at,
      :source,
      :external_ref
    ])
  end

  def render(%Grade{} = grade) do
    Map.take(grade, [:id, :enrollment_id, :label, :score, :max_score, :weight, :source])
  end

  def render(%Absence{} = absence) do
    Map.take(absence, [:id, :enrollment_id, :date, :count, :note, :source])
  end

  def render(%GradeSummary{} = summary) do
    Map.take(summary, [
      :weighted_average,
      :graded_weight,
      :remaining_weight,
      :passing_average,
      :status
    ])
  end

  def render(%AttendanceSummary{} = summary) do
    Map.take(summary, [:used, :limit, :remaining, :status])
  end

  def render(%SyncRun{} = run) do
    Map.take(run, [
      :id,
      :status,
      :sources,
      :semester_id,
      :counts,
      :error,
      :started_at,
      :finished_at
    ])
  end

  def render(%University{} = university),
    do: Map.take(university, [:id, :name, :acronym, :country])

  def render(%Unit{} = unit), do: Map.take(unit, [:id, :university_id, :name, :acronym])
  def render(%Course{} = course), do: Map.take(course, [:id, :unit_id, :name, :code])

  def render(%Discipline{} = discipline) do
    Map.take(discipline, [:id, :unit_id, :code, :name, :credits])
  end

  def render(%LoginKey{} = key), do: Map.take(key, [:key_id, :alg, :public_key])
  def render(%Blob{} = blob), do: Map.take(blob, [:blob, :expires_at])

  # The computed weekly schedule: a plain map of day -> slots.
  def render(%{days: days} = schedule) when not is_struct(schedule) do
    %{
      schedule
      | days: Map.new(days, fn {day, slots} -> {day, Enum.map(slots, &render_slot/1)} end)
    }
  end

  defp render_slot(slot) do
    %{slot | starts_at: hhmm(slot.starts_at), ends_at: hhmm(slot.ends_at)}
  end

  defp hhmm(%Time{} = time), do: Calendar.strftime(time, "%H:%M")
end

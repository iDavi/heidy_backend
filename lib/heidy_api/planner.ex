defmodule HeidyApi.Planner do
  @moduledoc """
  The student's academic life: semesters, enrollments, meetings, tasks,
  grades and absences, plus the computed schedule and summaries.

  Rows may be manual or imported from USP — same schemas, distinguished by
  `source`/`external_ref`. Imports upsert by `external_ref` and never
  overwrite manual rows.
  """

  alias HeidyApi.Accounts.User
  alias HeidyApi.Catalog
  alias HeidyApi.Planner.{Absence, AttendanceSummary, Enrollment, Grade, GradeSummary}
  alias HeidyApi.Planner.{Meeting, Schedule, Semester, Task}
  alias HeidyApi.{Ids, Page, Store}

  @type result(t) ::
          {:ok, t} | {:error, :not_found | {:conflict, String.t()} | {:validation, map()}}

  ## Semesters

  @spec create_semester(User.t(), map()) :: result(Semester.t())
  def create_semester(%User{} = user, attrs) do
    semester = struct!(%Semester{id: Ids.generate(), user_id: user.id, label: nil}, attrs)

    if Enum.any?(owned(:semesters, user), &same_period?(&1, semester)) do
      {:error, {:conflict, "A semester with this label or overlapping dates already exists"}}
    else
      {:ok, Store.put(:semesters, semester)}
    end
  end

  @spec list_semesters(User.t(), map()) :: Page.t()
  def list_semesters(%User{} = user, filters) do
    owned(:semesters, user)
    |> filter_by(:active, filters[:active])
    |> sort(filters[:sort], &{&1.label, &1.start_date})
    |> Page.paginate(filters.page, filters.page_size)
  end

  @spec fetch_semester(User.t(), String.t()) :: result(Semester.t())
  def fetch_semester(%User{} = user, id), do: fetch_owned(:semesters, user, id)

  @spec update_semester(Semester.t(), map()) :: {:ok, Semester.t()}
  def update_semester(%Semester{} = semester, attrs) do
    {:ok, Store.put(:semesters, struct!(semester, attrs))}
  end

  @spec delete_semester(User.t(), String.t()) :: :ok
  def delete_semester(%User{}, id), do: Store.delete(:semesters, id)

  ## Enrollments

  @spec create_enrollment(User.t(), map()) :: result(Enrollment.t())
  def create_enrollment(%User{} = user, attrs) do
    with {:ok, _semester} <- fetch_semester(user, attrs.semester_id),
         :ok <- ensure_discipline(attrs[:discipline_id]) do
      enrollment =
        struct!(%Enrollment{id: Ids.generate(), user_id: user.id, semester_id: nil}, attrs)

      if Enum.any?(owned(:enrollments, user), &same_class?(&1, enrollment)) do
        {:error, {:conflict, "This class is already in the semester"}}
      else
        {:ok, Store.put(:enrollments, enrollment)}
      end
    end
  end

  @spec list_enrollments(User.t(), map()) :: Page.t()
  def list_enrollments(%User{} = user, filters) do
    owned(:enrollments, user)
    |> filter_by(:semester_id, filters[:semester_id])
    |> filter_by(:source, filters[:source])
    |> Enum.map(&load_meetings/1)
    |> Page.paginate(filters.page, filters.page_size)
  end

  @spec fetch_enrollment(User.t(), String.t()) :: result(Enrollment.t())
  def fetch_enrollment(%User{} = user, id) do
    with {:ok, enrollment} <- fetch_owned(:enrollments, user, id) do
      {:ok, load_meetings(enrollment)}
    end
  end

  @spec update_enrollment(Enrollment.t(), map()) :: {:ok, Enrollment.t()}
  def update_enrollment(%Enrollment{} = enrollment, attrs) do
    {:ok, Store.put(:enrollments, struct!(enrollment, attrs))}
  end

  @spec delete_enrollment(User.t(), String.t()) :: :ok
  def delete_enrollment(%User{}, id), do: Store.delete(:enrollments, id)

  ## Meetings

  @spec create_meeting(Enrollment.t(), map()) :: result(Meeting.t())
  def create_meeting(%Enrollment{} = enrollment, attrs) do
    meeting =
      struct!(
        %Meeting{
          id: Ids.generate(),
          enrollment_id: enrollment.id,
          day_of_week: nil,
          starts_at: nil,
          ends_at: nil
        },
        attrs
      )

    with :ok <- validate_time_order(meeting) do
      if Enum.any?(meetings_of(enrollment.id), &Meeting.overlaps?(&1, meeting)) do
        {:error, {:conflict, "This time slot overlaps an existing meeting of the class"}}
      else
        {:ok, Store.put(:meetings, meeting)}
      end
    end
  end

  @spec list_meetings(Enrollment.t()) :: [Meeting.t()]
  def list_meetings(%Enrollment{id: enrollment_id}), do: meetings_of(enrollment_id)

  @spec fetch_meeting(User.t(), String.t()) :: result(Meeting.t())
  def fetch_meeting(%User{}, id), do: Store.fetch(:meetings, id)

  @spec update_meeting(Meeting.t(), map()) :: result(Meeting.t())
  def update_meeting(%Meeting{} = meeting, attrs) do
    updated = struct!(meeting, attrs)

    with :ok <- validate_time_order(updated) do
      {:ok, Store.put(:meetings, updated)}
    end
  end

  @spec delete_meeting(User.t(), String.t()) :: :ok
  def delete_meeting(%User{}, id), do: Store.delete(:meetings, id)

  ## Tasks

  @spec create_task(User.t(), map()) :: result(Task.t())
  def create_task(%User{} = user, attrs) do
    with :ok <- ensure_enrollment(user, attrs[:enrollment_id]) do
      {:ok,
       Store.put(:tasks, struct!(%Task{id: Ids.generate(), user_id: user.id, title: nil}, attrs))}
    end
  end

  @spec list_tasks(User.t(), map()) :: Page.t()
  def list_tasks(%User{} = user, filters) do
    owned(:tasks, user)
    |> filter_by(:status, filters[:status])
    |> filter_by(:kind, filters[:kind])
    |> filter_by(:enrollment_id, filters[:enrollment_id])
    |> filter_tasks_by_semester(filters[:semester_id])
    |> filter_due(filters[:due_before], filters[:due_after])
    |> sort(filters[:sort], & &1.due_at)
    |> Page.paginate(filters.page, filters.page_size)
  end

  @spec fetch_task(User.t(), String.t()) :: result(Task.t())
  def fetch_task(%User{} = user, id), do: fetch_owned(:tasks, user, id)

  @spec update_task(Task.t(), map()) :: {:ok, Task.t()}
  def update_task(%Task{} = task, attrs), do: {:ok, Store.put(:tasks, struct!(task, attrs))}

  @spec delete_task(User.t(), String.t()) :: :ok
  def delete_task(%User{}, id), do: Store.delete(:tasks, id)

  ## Grades

  @spec create_grade(Enrollment.t(), map()) :: result(Grade.t())
  def create_grade(%Enrollment{} = enrollment, attrs) do
    grade = struct!(%Grade{id: Ids.generate(), enrollment_id: enrollment.id, label: nil}, attrs)
    {:ok, Store.put(:grades, grade)}
  end

  @spec list_grades(Enrollment.t()) :: [Grade.t()]
  def list_grades(%Enrollment{id: enrollment_id}) do
    Enum.filter(Store.list(:grades), &(&1.enrollment_id == enrollment_id))
  end

  @spec grade_summary(Enrollment.t()) :: GradeSummary.t()
  def grade_summary(%Enrollment{} = enrollment) do
    enrollment |> list_grades() |> GradeSummary.compute()
  end

  @spec fetch_grade(User.t(), String.t()) :: result(Grade.t())
  def fetch_grade(%User{}, id), do: Store.fetch(:grades, id)

  @spec update_grade(Grade.t(), map()) :: {:ok, Grade.t()}
  def update_grade(%Grade{} = grade, attrs), do: {:ok, Store.put(:grades, struct!(grade, attrs))}

  @spec delete_grade(User.t(), String.t()) :: :ok
  def delete_grade(%User{}, id), do: Store.delete(:grades, id)

  ## Absences

  @spec create_absence(Enrollment.t(), map()) :: result(Absence.t())
  def create_absence(%Enrollment{} = enrollment, attrs) do
    absence =
      struct!(%Absence{id: Ids.generate(), enrollment_id: enrollment.id, date: nil}, attrs)

    {:ok, Store.put(:absences, absence)}
  end

  @spec list_absences(Enrollment.t()) :: [Absence.t()]
  def list_absences(%Enrollment{id: enrollment_id}) do
    Enum.filter(Store.list(:absences), &(&1.enrollment_id == enrollment_id))
  end

  @spec attendance_summary(Enrollment.t()) :: AttendanceSummary.t()
  def attendance_summary(%Enrollment{} = enrollment) do
    AttendanceSummary.compute(enrollment.absence_limit, list_absences(enrollment))
  end

  @spec delete_absence(User.t(), String.t()) :: :ok
  def delete_absence(%User{}, id), do: Store.delete(:absences, id)

  ## Schedule

  @spec schedule(User.t(), Semester.t()) :: Schedule.t()
  def schedule(%User{} = user, %Semester{} = semester) do
    owned(:enrollments, user)
    |> Enum.filter(&(&1.semester_id == semester.id))
    |> Enum.map(&load_meetings/1)
    |> Schedule.week(semester)
  end

  ## Shared helpers

  defp owned(collection, %User{id: user_id}) do
    Enum.filter(Store.list(collection), &(&1.user_id == user_id))
  end

  # Ownership is enforced on stored rows: a foreign row answers :not_found
  # (no existence leak). Demo fallback records belong to whoever asks.
  defp fetch_owned(collection, %User{id: user_id}, id) do
    case Store.get(collection, id) do
      %{user_id: owner} when owner != user_id ->
        {:error, :not_found}

      %{} = record ->
        {:ok, record}

      nil ->
        with {:ok, record} <- Store.fetch(collection, id) do
          {:ok, %{record | user_id: user_id}}
        end
    end
  end

  defp same_period?(%Semester{} = a, %Semester{} = b) do
    a.label == b.label or dates_overlap?(a, b)
  end

  defp dates_overlap?(a, b) do
    is_struct(a.start_date, Date) and is_struct(b.start_date, Date) and
      is_struct(a.end_date, Date) and is_struct(b.end_date, Date) and
      Date.compare(a.start_date, b.end_date) != :gt and
      Date.compare(b.start_date, a.end_date) != :gt
  end

  defp same_class?(%Enrollment{} = a, %Enrollment{} = b) do
    a.semester_id == b.semester_id and
      ((a.discipline_id != nil and a.discipline_id == b.discipline_id) or
         (a.title != nil and a.title == b.title))
  end

  defp ensure_discipline(nil), do: :ok

  defp ensure_discipline(discipline_id) do
    with {:ok, _discipline} <- Catalog.fetch_discipline(discipline_id), do: :ok
  end

  defp ensure_enrollment(_user, nil), do: :ok

  defp ensure_enrollment(user, enrollment_id) do
    with {:ok, _enrollment} <- fetch_enrollment(user, enrollment_id), do: :ok
  end

  defp validate_time_order(%Meeting{starts_at: %Time{} = starts, ends_at: %Time{} = ends}) do
    if Time.compare(ends, starts) == :gt do
      :ok
    else
      {:error, {:validation, %{"ends_at" => ["must be after starts_at"]}}}
    end
  end

  defp meetings_of(enrollment_id) do
    Enum.filter(Store.list(:meetings), &(&1.enrollment_id == enrollment_id))
  end

  defp load_meetings(%Enrollment{} = enrollment) do
    %{enrollment | meetings: meetings_of(enrollment.id)}
  end

  defp filter_by(items, _key, nil), do: items
  defp filter_by(items, key, value), do: Enum.filter(items, &(Map.get(&1, key) == value))

  defp filter_tasks_by_semester(tasks, nil), do: tasks

  defp filter_tasks_by_semester(tasks, semester_id) do
    enrollment_ids =
      Store.list(:enrollments)
      |> Enum.filter(&(&1.semester_id == semester_id))
      |> MapSet.new(& &1.id)

    Enum.filter(tasks, &(&1.enrollment_id in enrollment_ids))
  end

  defp filter_due(tasks, before_dt, after_dt) do
    tasks
    |> Enum.filter(fn task ->
      is_nil(before_dt) or (task.due_at && DateTime.compare(task.due_at, before_dt) != :gt)
    end)
    |> Enum.filter(fn task ->
      is_nil(after_dt) or (task.due_at && DateTime.compare(task.due_at, after_dt) != :lt)
    end)
  end

  defp sort(items, nil, _default_key), do: items

  defp sort(items, "-" <> field, _default_key) do
    Enum.sort_by(items, &Map.get(&1, String.to_existing_atom(field)), :desc)
  end

  defp sort(items, field, _default_key) do
    Enum.sort_by(items, &Map.get(&1, String.to_existing_atom(field)))
  end
end

defmodule HeidyApi.Planner do
  @moduledoc """
  The student's academic life: semesters, enrollments, meetings, tasks,
  grades and absences, plus the computed schedule and summaries.

  Rows may be manual or imported from USP - same schemas, distinguished by
  `source`/`external_ref`. Imports upsert by `external_ref` and never
  overwrite manual rows.
  """

  import Ecto.Query

  alias HeidyApi.Accounts.User
  alias HeidyApi.Catalog
  alias HeidyApi.Changeset
  alias HeidyApi.Planner.{Absence, AttendanceSummary, Enrollment, Grade, GradeSummary}
  alias HeidyApi.Planner.{Meeting, Schedule, Semester, Task}
  alias HeidyApi.{Demo, Ids, Page, Repo}

  @type result(t) ::
          {:ok, t} | {:error, :not_found | {:conflict, String.t()} | {:validation, map()}}

  ## Semesters

  @spec create_semester(User.t(), map()) :: result(Semester.t())
  def create_semester(%User{} = user, attrs) do
    attrs = Map.put(attrs, :user_id, user.id)
    changeset = changeset_for(Semester, attrs)

    with {:ok, semester} <- Changeset.apply_action(changeset, :insert),
         :ok <- ensure_unique_period(user, semester) do
      insert(changeset)
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

  @spec update_semester(Semester.t(), map()) :: result(Semester.t())
  def update_semester(%Semester{} = semester, attrs) do
    semester |> Semester.changeset(attrs) |> Repo.update() |> Changeset.normalize_result()
  end

  @spec delete_semester(User.t(), String.t()) :: :ok
  def delete_semester(%User{} = user, id) do
    Repo.delete_all(
      from(semester in Semester, where: semester.user_id == ^user.id and semester.id == ^id)
    )

    :ok
  end

  ## Enrollments

  @spec create_enrollment(User.t(), map()) :: result(Enrollment.t())
  def create_enrollment(%User{} = user, attrs) do
    with {:ok, _semester} <- fetch_semester(user, attrs.semester_id),
         :ok <- ensure_discipline(attrs[:discipline_id]) do
      attrs = Map.put(attrs, :user_id, user.id)
      changeset = changeset_for(Enrollment, attrs)

      with {:ok, enrollment} <- Changeset.apply_action(changeset, :insert),
           :ok <- ensure_unique_class(user, enrollment),
           {:ok, enrollment} <- insert(changeset) do
        {:ok, load_meetings(enrollment)}
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

  @spec update_enrollment(Enrollment.t(), map()) :: result(Enrollment.t())
  def update_enrollment(%Enrollment{} = enrollment, attrs) do
    enrollment
    |> Enrollment.changeset(attrs)
    |> Repo.update()
    |> Changeset.normalize_result()
    |> preload_meetings()
  end

  @spec delete_enrollment(User.t(), String.t()) :: :ok
  def delete_enrollment(%User{} = user, id) do
    Repo.delete_all(
      from(enrollment in Enrollment,
        where: enrollment.user_id == ^user.id and enrollment.id == ^id
      )
    )

    :ok
  end

  ## Meetings

  @spec create_meeting(Enrollment.t(), map()) :: result(Meeting.t())
  def create_meeting(%Enrollment{} = enrollment, attrs) do
    attrs = Map.put(attrs, :enrollment_id, enrollment.id)
    changeset = changeset_for(Meeting, attrs)

    with {:ok, meeting} <- Changeset.apply_action(changeset, :insert),
         :ok <- ensure_no_overlap(enrollment, meeting) do
      insert(changeset)
    end
  end

  @spec list_meetings(Enrollment.t()) :: [Meeting.t()]
  def list_meetings(%Enrollment{id: enrollment_id}), do: meetings_of(enrollment_id)

  @spec fetch_meeting(User.t(), String.t()) :: result(Meeting.t())
  def fetch_meeting(%User{} = user, id), do: fetch_child(:meetings, user, id)

  @spec update_meeting(Meeting.t(), map()) :: result(Meeting.t())
  def update_meeting(%Meeting{} = meeting, attrs) do
    meeting |> Meeting.changeset(attrs) |> Repo.update() |> Changeset.normalize_result()
  end

  @spec delete_meeting(User.t(), String.t()) :: :ok
  def delete_meeting(%User{} = user, id), do: delete_child(:meetings, user, id)

  ## Tasks

  @spec create_task(User.t(), map()) :: result(Task.t())
  def create_task(%User{} = user, attrs) do
    with :ok <- ensure_enrollment(user, attrs[:enrollment_id]) do
      attrs = Map.put(attrs, :user_id, user.id)
      %Task{} |> Task.changeset(attrs) |> Repo.insert() |> Changeset.normalize_result()
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

  @spec update_task(Task.t(), map()) :: result(Task.t())
  def update_task(%Task{} = task, attrs) do
    task |> Task.changeset(attrs) |> Repo.update() |> Changeset.normalize_result()
  end

  @spec delete_task(User.t(), String.t()) :: :ok
  def delete_task(%User{} = user, id) do
    Repo.delete_all(from(task in Task, where: task.user_id == ^user.id and task.id == ^id))
    :ok
  end

  ## Grades

  @spec create_grade(Enrollment.t(), map()) :: result(Grade.t())
  def create_grade(%Enrollment{} = enrollment, attrs) do
    attrs = Map.put(attrs, :enrollment_id, enrollment.id)
    %Grade{} |> Grade.changeset(attrs) |> Repo.insert() |> Changeset.normalize_result()
  end

  @spec list_grades(Enrollment.t()) :: [Grade.t()]
  def list_grades(%Enrollment{id: enrollment_id}) do
    Repo.all(from(grade in Grade, where: grade.enrollment_id == ^enrollment_id))
  end

  @spec grade_summary(Enrollment.t()) :: GradeSummary.t()
  def grade_summary(%Enrollment{} = enrollment) do
    enrollment |> list_grades() |> GradeSummary.compute()
  end

  @spec fetch_grade(User.t(), String.t()) :: result(Grade.t())
  def fetch_grade(%User{} = user, id), do: fetch_child(:grades, user, id)

  @spec update_grade(Grade.t(), map()) :: result(Grade.t())
  def update_grade(%Grade{} = grade, attrs) do
    grade |> Grade.changeset(attrs) |> Repo.update() |> Changeset.normalize_result()
  end

  @spec delete_grade(User.t(), String.t()) :: :ok
  def delete_grade(%User{} = user, id), do: delete_child(:grades, user, id)

  ## Absences

  @spec create_absence(Enrollment.t(), map()) :: result(Absence.t())
  def create_absence(%Enrollment{} = enrollment, attrs) do
    attrs = Map.put(attrs, :enrollment_id, enrollment.id)
    %Absence{} |> Absence.changeset(attrs) |> Repo.insert() |> Changeset.normalize_result()
  end

  @spec list_absences(Enrollment.t()) :: [Absence.t()]
  def list_absences(%Enrollment{id: enrollment_id}) do
    Repo.all(from(absence in Absence, where: absence.enrollment_id == ^enrollment_id))
  end

  @spec attendance_summary(Enrollment.t()) :: AttendanceSummary.t()
  def attendance_summary(%Enrollment{} = enrollment) do
    AttendanceSummary.compute(enrollment.absence_limit, list_absences(enrollment))
  end

  @spec delete_absence(User.t(), String.t()) :: :ok
  def delete_absence(%User{} = user, id), do: delete_child(:absences, user, id)

  ## Schedule

  @spec schedule(User.t(), Semester.t()) :: Schedule.t()
  def schedule(%User{} = user, %Semester{} = semester) do
    owned(:enrollments, user)
    |> Enum.filter(&(&1.semester_id == semester.id))
    |> Enum.map(&load_meetings/1)
    |> Schedule.week(semester)
  end

  ## Shared helpers

  defp changeset_for(module, attrs) do
    module.__struct__()
    |> module.changeset(attrs)
  end

  defp insert(%Ecto.Changeset{} = changeset) do
    changeset
    |> Repo.insert()
    |> Changeset.normalize_result()
  end

  defp owned(:semesters, %User{id: user_id}) do
    Repo.all(from(semester in Semester, where: semester.user_id == ^user_id))
  end

  defp owned(:enrollments, %User{id: user_id}) do
    Repo.all(from(enrollment in Enrollment, where: enrollment.user_id == ^user_id))
  end

  defp owned(:tasks, %User{id: user_id}) do
    Repo.all(from(task in Task, where: task.user_id == ^user_id))
  end

  defp fetch_owned(collection, %User{} = user, id) do
    cond do
      not Ids.valid?(id) ->
        {:error, :not_found}

      Ids.reserved?(id) ->
        {:error, :not_found}

      record = get_owned(collection, user, id) ->
        {:ok, record}

      persisted?(collection, id) ->
        {:error, :not_found}

      true ->
        fetch_demo_owned(collection, user, id)
    end
  end

  defp get_owned(:semesters, user, id) do
    Repo.one(
      from(semester in Semester, where: semester.user_id == ^user.id and semester.id == ^id)
    )
  end

  defp get_owned(:enrollments, user, id) do
    Repo.one(
      from(enrollment in Enrollment,
        where: enrollment.user_id == ^user.id and enrollment.id == ^id
      )
    )
  end

  defp get_owned(:tasks, user, id) do
    Repo.one(from(task in Task, where: task.user_id == ^user.id and task.id == ^id))
  end

  defp persisted?(:semesters, id),
    do: Repo.exists?(from(semester in Semester, where: semester.id == ^id))

  defp persisted?(:enrollments, id),
    do: Repo.exists?(from(enrollment in Enrollment, where: enrollment.id == ^id))

  defp persisted?(:tasks, id), do: Repo.exists?(from(task in Task, where: task.id == ^id))

  defp fetch_child(collection, %User{} = user, id) do
    cond do
      not Ids.valid?(id) -> {:error, :not_found}
      Ids.reserved?(id) -> {:error, :not_found}
      record = get_child(collection, user, id) -> {:ok, record}
      child_persisted?(collection, id) -> {:error, :not_found}
      true -> fetch_demo_child(collection, user, id)
    end
  end

  defp get_child(:meetings, user, id) do
    Repo.one(
      from(meeting in Meeting,
        join: enrollment in Enrollment,
        on: enrollment.id == meeting.enrollment_id,
        where: enrollment.user_id == ^user.id and meeting.id == ^id,
        select: meeting
      )
    )
  end

  defp get_child(:grades, user, id) do
    Repo.one(
      from(grade in Grade,
        join: enrollment in Enrollment,
        on: enrollment.id == grade.enrollment_id,
        where: enrollment.user_id == ^user.id and grade.id == ^id,
        select: grade
      )
    )
  end

  defp get_child(:absences, user, id) do
    Repo.one(
      from(absence in Absence,
        join: enrollment in Enrollment,
        on: enrollment.id == absence.enrollment_id,
        where: enrollment.user_id == ^user.id and absence.id == ^id,
        select: absence
      )
    )
  end

  defp child_persisted?(:meetings, id),
    do: Repo.exists?(from(meeting in Meeting, where: meeting.id == ^id))

  defp child_persisted?(:grades, id),
    do: Repo.exists?(from(grade in Grade, where: grade.id == ^id))

  defp child_persisted?(:absences, id),
    do: Repo.exists?(from(absence in Absence, where: absence.id == ^id))

  defp delete_child(collection, %User{} = user, id) do
    case fetch_child(collection, user, id) do
      {:ok, record} ->
        {:ok, _record} = Repo.delete(record)
        :ok

      {:error, :not_found} ->
        :ok
    end
  end

  defp fetch_demo_owned(collection, user, id) do
    with {:ok, record} <- Demo.fetch(collection, id) do
      persist_demo(collection, %{record | user_id: user.id}, user)
    end
  end

  defp fetch_demo_child(collection, user, id) do
    with {:ok, record} <- Demo.fetch(collection, id) do
      persist_demo(collection, record, user)
    end
  end

  defp persist_demo(:semesters, %Semester{} = semester, _user) do
    %Semester{}
    |> Semester.changeset(Map.from_struct(semester))
    |> Repo.insert(on_conflict: :nothing)

    {:ok, Repo.get!(Semester, semester.id)}
  end

  defp persist_demo(:enrollments, %Enrollment{} = enrollment, user) do
    ensure_demo_semester(user, enrollment.semester_id)

    attrs =
      enrollment
      |> Map.from_struct()
      |> Map.put(:user_id, user.id)

    %Enrollment{} |> Enrollment.changeset(attrs) |> Repo.insert(on_conflict: :nothing)
    {:ok, Repo.get!(Enrollment, enrollment.id)}
  end

  defp persist_demo(:tasks, %Task{} = task, _user) do
    %Task{} |> Task.changeset(Map.from_struct(task)) |> Repo.insert(on_conflict: :nothing)
    {:ok, Repo.get!(Task, task.id)}
  end

  defp persist_demo(:meetings, %Meeting{} = meeting, user) do
    ensure_demo_enrollment(user, meeting.enrollment_id)

    %Meeting{}
    |> Meeting.changeset(Map.from_struct(meeting))
    |> Repo.insert(on_conflict: :nothing)

    {:ok, Repo.get!(Meeting, meeting.id)}
  end

  defp persist_demo(:grades, %Grade{} = grade, user) do
    ensure_demo_enrollment(user, grade.enrollment_id)
    %Grade{} |> Grade.changeset(Map.from_struct(grade)) |> Repo.insert(on_conflict: :nothing)
    {:ok, Repo.get!(Grade, grade.id)}
  end

  defp persist_demo(:absences, %Absence{} = absence, user) do
    ensure_demo_enrollment(user, absence.enrollment_id)

    %Absence{}
    |> Absence.changeset(Map.from_struct(absence))
    |> Repo.insert(on_conflict: :nothing)

    {:ok, Repo.get!(Absence, absence.id)}
  end

  defp ensure_demo_semester(user, semester_id) do
    unless Repo.get(Semester, semester_id) do
      {:ok, semester} = Demo.fetch(:semesters, semester_id)
      persist_demo(:semesters, %{semester | user_id: user.id}, user)
    end
  end

  defp ensure_demo_enrollment(user, enrollment_id) do
    unless Repo.get(Enrollment, enrollment_id) do
      {:ok, enrollment} = Demo.fetch(:enrollments, enrollment_id)
      persist_demo(:enrollments, %{enrollment | user_id: user.id}, user)
    end
  end

  defp ensure_unique_period(user, semester) do
    if Enum.any?(owned(:semesters, user), &same_period?(&1, semester)) do
      {:error, {:conflict, "A semester with this label or overlapping dates already exists"}}
    else
      :ok
    end
  end

  defp ensure_unique_class(user, enrollment) do
    if Enum.any?(owned(:enrollments, user), &same_class?(&1, enrollment)) do
      {:error, {:conflict, "This class is already in the semester"}}
    else
      :ok
    end
  end

  defp ensure_no_overlap(enrollment, meeting) do
    if Enum.any?(meetings_of(enrollment.id), &Meeting.overlaps?(&1, meeting)) do
      {:error, {:conflict, "This time slot overlaps an existing meeting of the class"}}
    else
      :ok
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

  defp meetings_of(enrollment_id) do
    Repo.all(from(meeting in Meeting, where: meeting.enrollment_id == ^enrollment_id))
  end

  defp load_meetings(%Enrollment{} = enrollment) do
    Repo.preload(enrollment, :meetings, force: true)
  end

  defp filter_by(items, _key, nil), do: items
  defp filter_by(items, key, value), do: Enum.filter(items, &(Map.get(&1, key) == value))

  defp filter_tasks_by_semester(tasks, nil), do: tasks

  defp filter_tasks_by_semester(tasks, semester_id) do
    enrollment_ids =
      Repo.all(
        from(enrollment in Enrollment,
          where: enrollment.semester_id == ^semester_id,
          select: enrollment.id
        )
      )
      |> MapSet.new()

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

  defp preload_meetings({:ok, %Enrollment{} = enrollment}), do: {:ok, load_meetings(enrollment)}
  defp preload_meetings(error), do: error
end

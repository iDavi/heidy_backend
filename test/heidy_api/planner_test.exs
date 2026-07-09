defmodule HeidyApi.PlannerTest do
  use HeidyApi.DataCase, async: true

  alias HeidyApi.Planner
  alias HeidyApi.Planner.{Absence, Enrollment, Grade, Meeting, Semester, Task}

  describe "schema changesets" do
    test "semester validates date order" do
      changeset =
        Semester.changeset(%Semester{}, %{
          user_id: unique_id(),
          label: "2026.1",
          start_date: ~D[2026-07-10],
          end_date: ~D[2026-02-01]
        })

      refute changeset.valid?
      assert {"must be on or after start_date", _opts} = changeset.errors[:end_date]
    end

    test "meeting validates time order" do
      changeset =
        Meeting.changeset(%Meeting{}, %{
          enrollment_id: unique_id(),
          day_of_week: 2,
          starts_at: ~T[10:00:00],
          ends_at: ~T[08:00:00]
        })

      refute changeset.valid?
      assert {"must be after starts_at", _opts} = changeset.errors[:ends_at]
    end

    test "task validates persisted enum fields" do
      changeset =
        Task.changeset(%Task{}, %{
          user_id: unique_id(),
          title: "Lista",
          kind: "quiz",
          status: "late",
          priority: "urgent"
        })

      refute changeset.valid?
      assert Keyword.has_key?(changeset.errors, :kind)
      assert Keyword.has_key?(changeset.errors, :status)
      assert Keyword.has_key?(changeset.errors, :priority)
    end
  end

  describe "semesters" do
    test "creates, lists, updates, and deletes semesters through Repo-backed contexts" do
      user = user_fixture()

      assert {:ok, semester} =
               Planner.create_semester(user, %{
                 label: "2026.1",
                 start_date: ~D[2026-02-01],
                 end_date: ~D[2026-07-15]
               })

      assert %{items: [listed], total: 1} =
               Planner.list_semesters(user, %{page: 1, page_size: 10})

      assert listed.id == semester.id

      assert {:ok, updated} = Planner.update_semester(semester, %{active: false})
      assert updated.active == false

      assert :ok = Planner.delete_semester(user, semester.id)
      assert {:error, :not_found} = Planner.fetch_semester(user, semester.id)
    end

    test "rejects duplicate or overlapping semesters for the same user" do
      user = user_fixture()
      attrs = %{label: "2026.1", start_date: ~D[2026-02-01], end_date: ~D[2026-07-15]}

      assert {:ok, _semester} = Planner.create_semester(user, attrs)
      assert {:error, {:conflict, detail}} = Planner.create_semester(user, attrs)
      assert detail =~ "semester"
    end
  end

  describe "enrollments and nested ownership" do
    test "creates enrollments and rejects duplicate classes in the same semester" do
      user = user_fixture()
      semester = semester_fixture(user)

      attrs = %{
        semester_id: semester.id,
        title: "MAC0110 Introducao a Computacao",
        discipline_id: nil
      }

      assert {:ok, %Enrollment{} = enrollment} = Planner.create_enrollment(user, attrs)
      assert enrollment.source == "manual"

      assert {:error, {:conflict, _detail}} = Planner.create_enrollment(user, attrs)
    end

    test "does not expose meetings, grades, or absences owned by another user" do
      owner = user_fixture()
      stranger = user_fixture()
      enrollment = enrollment_fixture(owner)
      meeting = meeting_fixture(enrollment)
      grade = grade_fixture(enrollment)
      absence = absence_fixture(enrollment)

      assert {:error, :not_found} = Planner.fetch_meeting(stranger, meeting.id)
      assert {:error, :not_found} = Planner.fetch_grade(stranger, grade.id)

      assert :ok = Planner.delete_absence(stranger, absence.id)
      assert Repo.get!(Absence, absence.id)
    end

    test "rejects overlapping meetings in one enrollment" do
      user = user_fixture()
      enrollment = enrollment_fixture(user)

      assert {:ok, _meeting} =
               Planner.create_meeting(enrollment, %{
                 day_of_week: 2,
                 starts_at: ~T[08:00:00],
                 ends_at: ~T[10:00:00]
               })

      assert {:error, {:conflict, detail}} =
               Planner.create_meeting(enrollment, %{
                 day_of_week: 2,
                 starts_at: ~T[09:00:00],
                 ends_at: ~T[11:00:00]
               })

      assert detail =~ "overlaps"
    end
  end

  describe "tasks, grades, absences, and summaries" do
    test "tasks are scoped to the current user" do
      owner = user_fixture()
      stranger = user_fixture()
      task = task_fixture(owner)

      assert {:ok, fetched} = Planner.fetch_task(owner, task.id)
      assert fetched.id == task.id
      assert {:error, :not_found} = Planner.fetch_task(stranger, task.id)
    end

    test "grade and attendance summaries read persisted child rows" do
      user = user_fixture()
      enrollment = enrollment_fixture(user, %{absence_limit: 4})

      assert {:ok, %Grade{}} =
               Planner.create_grade(enrollment, %{
                 label: "P1",
                 score: 8.0,
                 max_score: 10.0,
                 weight: 0.5
               })

      assert {:ok, %Absence{}} =
               Planner.create_absence(enrollment, %{date: ~D[2026-09-12], count: 2})

      grade_summary = Planner.grade_summary(enrollment)
      attendance_summary = Planner.attendance_summary(enrollment)

      assert grade_summary.weighted_average == 8.0
      assert attendance_summary.used == 2
      assert attendance_summary.remaining == 2
    end
  end
end

defmodule HeidyApi.Fixtures do
  @moduledoc false

  alias HeidyApi.Accounts.User
  alias HeidyApi.Planner.{Absence, Enrollment, Grade, Meeting, Semester, Task}
  alias HeidyApi.Repo

  def unique_id do
    HeidyApi.Ids.generate()
  end

  def user_fixture(attrs \\ %{}) do
    attrs =
      Map.merge(
        %{
          usp_username: unique_usp_username(),
          name: "Estudante Teste",
          email: "student#{System.unique_integer([:positive])}@example.com"
        },
        attrs
      )

    %User{} |> User.changeset(attrs) |> Repo.insert!()
  end

  def semester_fixture(user, attrs \\ %{}) do
    attrs =
      Map.merge(
        %{
          user_id: user.id,
          label: "2026.#{System.unique_integer([:positive])}",
          start_date: ~D[2026-02-02],
          end_date: ~D[2026-07-10],
          active: true
        },
        attrs
      )

    %Semester{} |> Semester.changeset(attrs) |> Repo.insert!()
  end

  def enrollment_fixture(user, attrs \\ %{}) do
    semester = Map.get_lazy(attrs, :semester, fn -> semester_fixture(user) end)
    attrs = Map.delete(attrs, :semester)

    attrs =
      Map.merge(
        %{
          user_id: user.id,
          semester_id: semester.id,
          title: "ACH2016 Inteligencia Artificial",
          professor: "Profa. Ana",
          credits: 4,
          color: "#2F80ED",
          absence_limit: 20
        },
        attrs
      )

    %Enrollment{} |> Enrollment.changeset(attrs) |> Repo.insert!()
  end

  def meeting_fixture(enrollment, attrs \\ %{}) do
    attrs =
      Map.merge(
        %{
          enrollment_id: enrollment.id,
          day_of_week: 2,
          starts_at: ~T[08:00:00],
          ends_at: ~T[10:00:00],
          location: "IME B-12"
        },
        attrs
      )

    %Meeting{} |> Meeting.changeset(attrs) |> Repo.insert!()
  end

  def task_fixture(user, attrs \\ %{}) do
    attrs =
      Map.merge(
        %{
          user_id: user.id,
          title: "Lista 1",
          kind: "assignment",
          status: "todo",
          priority: "normal",
          due_at: ~U[2026-08-20 23:59:00Z]
        },
        attrs
      )

    %Task{} |> Task.changeset(attrs) |> Repo.insert!()
  end

  def grade_fixture(enrollment, attrs \\ %{}) do
    attrs =
      Map.merge(
        %{
          enrollment_id: enrollment.id,
          label: "P1",
          score: 8.5,
          max_score: 10.0,
          weight: 1.0
        },
        attrs
      )

    %Grade{} |> Grade.changeset(attrs) |> Repo.insert!()
  end

  def absence_fixture(enrollment, attrs \\ %{}) do
    attrs =
      Map.merge(
        %{
          enrollment_id: enrollment.id,
          date: ~D[2026-09-12],
          count: 1,
          note: "medical"
        },
        attrs
      )

    %Absence{} |> Absence.changeset(attrs) |> Repo.insert!()
  end

  defp unique_usp_username do
    (1_000_000 + System.unique_integer([:positive])) |> Integer.to_string()
  end
end

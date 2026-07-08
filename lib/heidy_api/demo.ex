defmodule HeidyApi.Demo do
  @moduledoc """
  The deterministic dataset `HeidyApi.Store` serves while real persistence
  does not exist yet.

  Any well-formed, non-reserved id resolves to the collection's demo record
  (carrying the requested id), so every read/update/delete flow of the API
  can be exercised end-to-end. The catalog is a small static USP sample.
  Remove this module when the database-backed repo lands.
  """

  alias HeidyApi.Accounts.User
  alias HeidyApi.Catalog.{Course, Discipline, Unit, University}
  alias HeidyApi.Planner.{Absence, Enrollment, Grade, Meeting, Semester, Task}
  alias HeidyApi.Usp.SyncRun

  @user_id "11111111-1111-4111-8111-111111111111"
  @usp_id "22222222-2222-4222-8222-222222222222"

  @doc "The demo student every session starts as."
  @spec user() :: User.t()
  def user do
    %User{id: @user_id, usp_username: "1234567", name: "Estudante de Demonstração"}
  end

  @doc "Resolves a demo record for `collection` under the requested `id`."
  @spec fetch(HeidyApi.Store.collection(), String.t()) ::
          {:ok, struct()} | {:error, :not_found}
  def fetch(collection, id) do
    case build(collection, id) do
      nil -> {:error, :not_found}
      record -> {:ok, record}
    end
  end

  @doc "The static demo catalog for `collection`."
  @spec catalog(:universities | :units | :disciplines | :courses) :: [struct()]
  def catalog(:universities), do: [university(@usp_id)]

  def catalog(:units) do
    [
      %Unit{
        id: "33333333-3333-4333-8333-333333333331",
        university_id: @usp_id,
        name: "Escola de Artes, Ciências e Humanidades",
        acronym: "EACH"
      },
      %Unit{
        id: "33333333-3333-4333-8333-333333333332",
        university_id: @usp_id,
        name: "Instituto de Matemática e Estatística",
        acronym: "IME"
      }
    ]
  end

  def catalog(:disciplines) do
    [
      %Discipline{
        id: "44444444-4444-4444-8444-444444444441",
        unit_id: "33333333-3333-4333-8333-333333333332",
        code: "MAC0110",
        name: "Introdução à Computação",
        credits: 4
      },
      %Discipline{
        id: "44444444-4444-4444-8444-444444444442",
        unit_id: "33333333-3333-4333-8333-333333333331",
        code: "ACH2016",
        name: "Inteligência Artificial",
        credits: 4
      }
    ]
  end

  def catalog(:courses) do
    [
      %Course{
        id: "55555555-5555-4555-8555-555555555551",
        unit_id: "33333333-3333-4333-8333-333333333331",
        name: "Bacharelado em Sistemas de Informação",
        code: "86200"
      }
    ]
  end

  defp build(:users, id), do: %{user() | id: id}
  defp build(:universities, id), do: university(id)
  defp build(:units, id), do: %{hd(catalog(:units)) | id: id}
  defp build(:disciplines, id), do: %{hd(catalog(:disciplines)) | id: id}
  defp build(:courses, id), do: %{hd(catalog(:courses)) | id: id}

  defp build(:semesters, id) do
    %Semester{
      id: id,
      user_id: @user_id,
      label: "2026.1",
      start_date: ~D[2026-02-02],
      end_date: ~D[2026-07-10],
      active: true
    }
  end

  defp build(:enrollments, id) do
    %Enrollment{
      id: id,
      user_id: @user_id,
      semester_id: "66666666-6666-4666-8666-666666666666",
      title: "ACH2016 Inteligência Artificial",
      professor: "Profa. Ana",
      credits: 4,
      color: "#2F80ED",
      absence_limit: 20
    }
  end

  defp build(:meetings, id) do
    %Meeting{
      id: id,
      enrollment_id: "77777777-7777-4777-8777-777777777777",
      day_of_week: 2,
      starts_at: ~T[08:00:00],
      ends_at: ~T[10:00:00],
      location: "EACH A1-05"
    }
  end

  defp build(:tasks, id) do
    %Task{id: id, user_id: @user_id, title: "Lista 1", due_at: ~U[2026-08-20 23:59:00Z]}
  end

  defp build(:grades, id) do
    %Grade{id: id, enrollment_id: "77777777-7777-4777-8777-777777777777", label: "P1", score: 8.5}
  end

  defp build(:absences, id) do
    %Absence{
      id: id,
      enrollment_id: "77777777-7777-4777-8777-777777777777",
      date: ~D[2026-09-12],
      count: 1
    }
  end

  defp build(:sync_runs, id) do
    %SyncRun{
      id: id,
      user_id: @user_id,
      sources: ["schedule"],
      status: "succeeded",
      counts: %{"schedule" => 0}
    }
  end

  defp build(_collection, _id), do: nil

  defp university(id) do
    %University{id: id, name: "Universidade de São Paulo", acronym: "USP", country: "BR"}
  end
end

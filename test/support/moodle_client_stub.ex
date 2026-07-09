defmodule HeidyApi.MoodleClientStub do
  @moduledoc false

  @behaviour HeidyApi.Moodle.Client

  alias HeidyApi.Moodle.{Activity, ActivityDetail, Assignment, Course, CourseDetail, Session}

  @impl true
  def login("000000", _password), do: {:error, :invalid_credentials}
  def login(username, _password), do: {:ok, %Session{username: username}}

  @impl true
  def fetch_assignments(%Session{}) do
    {:ok,
     [
       %Assignment{
         external_ref: "moodle:event:9001",
         title: "Lista Moodle",
         course_name: "ACH2016 Inteligencia Artificial",
         due_at: ~U[2026-03-20 23:59:00Z],
         url: "https://edisciplinas.usp.br/mod/assign/view.php?id=9001"
       }
     ]}
  end

  @impl true
  def fetch_courses(%Session{}) do
    {:ok,
     [
       %Course{
         id: 101,
         code: "ACH2016",
         name: "Inteligencia Artificial",
         title: "ACH2016 Inteligencia Artificial",
         url: "https://edisciplinas.usp.br/course/view.php?id=101"
       }
     ]}
  end

  @impl true
  def fetch_course(%Session{}, 101) do
    {:ok,
     %CourseDetail{
       id: 101,
       title: "ACH2016 Inteligencia Artificial",
       activities: [
         %Activity{
           id: 9001,
           title: "Lista Moodle",
           kind: "Tarefa",
           url: "https://edisciplinas.usp.br/mod/assign/view.php?id=9001"
         }
       ]
     }}
  end

  def fetch_course(%Session{}, _course_id), do: {:error, :unavailable}

  @impl true
  def fetch_activity(%Session{}, "https://edisciplinas.usp.br/mod/assign/view.php?id=9001") do
    {:ok,
     %ActivityDetail{
       id: 9001,
       title: "Lista Moodle",
       content: "Leia o enunciado e entregue a atividade.",
       links: [],
       file: nil
     }}
  end

  def fetch_activity(%Session{}, _url), do: {:error, :unavailable}
end

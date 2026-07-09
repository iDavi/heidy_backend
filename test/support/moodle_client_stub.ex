defmodule HeidyApi.MoodleClientStub do
  @moduledoc false

  @behaviour HeidyApi.Moodle.Client

  alias HeidyApi.Moodle.{Assignment, Session}

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
end

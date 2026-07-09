defmodule HeidyApi.Moodle.Client.EdiciplinasTest do
  use ExUnit.Case, async: true

  alias HeidyApi.Moodle.Client.Ediciplinas

  test "normalizes Moodle calendar events into planner assignments" do
    payload = [
      %{
        "error" => false,
        "data" => %{
          "events" => [
            %{
              "id" => 42,
              "name" => "Projeto final",
              "course" => %{"fullname" => "ACH2016 Inteligencia Artificial"},
              "url" => "https://edisciplinas.usp.br/mod/assign/view.php?id=42",
              "timestart" => 1_773_446_400,
              "modulename" => "assign"
            },
            %{
              "id" => 43,
              "name" => "Prova 1",
              "modulename" => "quiz",
              "timesort" => 1_773_532_800
            }
          ]
        }
      }
    ]

    assert [assignment, quiz] = Ediciplinas.assignments_from_payload(payload)
    assert assignment.external_ref == "moodle:event:42"
    assert assignment.course_name == "ACH2016 Inteligencia Artificial"
    assert assignment.kind == "assignment"
    assert assignment.due_at == ~U[2026-03-14 00:00:00Z]
    assert quiz.kind == "exam"
  end
end

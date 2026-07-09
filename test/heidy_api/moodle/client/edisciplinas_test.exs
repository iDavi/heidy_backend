defmodule HeidyApi.Moodle.Client.EdiciplinasTest do
  use ExUnit.Case, async: true

  alias HeidyApi.Moodle.Client.Ediciplinas

  test "parses authenticated course and activity pages" do
    courses =
      Ediciplinas.courses_from_html("""
      <h5><a href="/course/view.php?id=101">ACH2016 Inteligencia Artificial</a></h5>
      """)

    assert [%{id: 101, title: "ACH2016 Inteligencia Artificial"}] = courses

    assert {:ok, course} =
             Ediciplinas.course_from_html(
               """
               <h1>ACH2016 Inteligencia Artificial</h1>
               <main><a href="/mod/assign/view.php?id=9001">Lista 1</a></main>
               """,
               101
             )

    assert [%{id: 9001, title: "Lista 1", kind: "Tarefa"}] = course.activities

    assert {:ok, activity} =
             Ediciplinas.activity_from_html(
               """
               <h1>Lista 1</h1>
               <main><p>Leia o enunciado.</p><a href="/mod/resource/view.php?id=30">Material</a></main>
               """,
               9001
             )

    assert activity.content =~ "Leia o enunciado"
    assert [%{label: "Material"}] = activity.links
  end
end

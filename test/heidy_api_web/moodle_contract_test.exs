defmodule HeidyApiWeb.MoodleContractTest do
  @moduledoc "Contract for read-only e-Disciplinas routes."
  use HeidyApi.ApiContractCase, async: true

  describe "Moodle reader" do
    test "a student can read courses, a course, and an activity with a credential blob" do
      # Arrange
      request = %{"credential_blob" => credential_blob()}

      # Act
      courses_response = post(auth_conn(), api_path("/moodle/courses"), Jason.encode!(request))
      courses = courses_response |> json_response(200) |> assert_collection_envelope()
      course_response = post(auth_conn(), api_path("/moodle/courses/101"), Jason.encode!(request))

      activity_response =
        post(
          auth_conn(),
          api_path("/moodle/activity"),
          Jason.encode!(
            Map.put(request, "url", "https://edisciplinas.usp.br/mod/assign/view.php?id=9001")
          )
        )

      # Assert
      assert [%{"id" => 101, "title" => title}] = courses
      assert is_binary(title)

      course = course_response |> json_response(200) |> assert_data_envelope()
      assert %{"id" => 101, "activities" => [%{"id" => 9001}]} = course

      activity = activity_response |> json_response(200) |> assert_data_envelope()
      assert %{"id" => 9001, "content" => content} = activity
      assert is_binary(content)
    end

    test "Moodle reader validates a credential blob and activity URL" do
      # Act
      response = post(auth_conn(), api_path("/moodle/activity"), Jason.encode!(%{"url" => ""}))

      # Assert
      body = json_response(response, 422)
      assert_validation_error(body, "credential_blob")
      assert_validation_error(body, "url")
    end
  end
end

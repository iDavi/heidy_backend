defmodule HeidyApiWeb.GradesContractTest do
  @moduledoc "Contract for the grade routes and the computed grade summary."
  use HeidyApi.ApiContractCase, async: true

  describe "grades" do
    test "a student can record a grade for a class" do
      # Arrange
      enrollment_id = uuid()
      attributes = grade_input()
      expected = %{"title" => "P1", "score" => 8.5, "max_score" => 10.0}

      # Act
      response =
        post(
          auth_conn(),
          api_path("/enrollments/#{enrollment_id}/grades"),
          Jason.encode!(attributes)
        )

      # Assert
      grade = response |> json_response(201) |> assert_data_envelope()
      assert expected == Map.take(grade, ["title", "score", "max_score"])
    end

    test "a student can list the grades of a class" do
      # Arrange
      enrollment_id = uuid()

      # Act
      response = get(auth_conn(), api_path("/enrollments/#{enrollment_id}/grades"))

      # Assert
      response
      |> json_response(200)
      |> assert_list_envelope()
    end

    test "a student can see a computed grade summary for a class" do
      # Arrange
      enrollment_id = uuid()

      # Act
      response = get(auth_conn(), api_path("/enrollments/#{enrollment_id}/grades/summary"))

      # Assert
      summary = response |> json_response(200) |> assert_data_envelope()
      assert %{"current_score" => current_score, "max_score" => max_score} = summary
      assert is_number(current_score)
      assert is_number(max_score)
    end

    test "a student can update a grade's score" do
      # Arrange
      grade_id = uuid()
      changes = %{"score" => 9.0}
      expected_score = 9.0

      # Act
      response = patch(auth_conn(), api_path("/grades/#{grade_id}"), Jason.encode!(changes))

      # Assert
      grade = response |> json_response(200) |> assert_data_envelope()
      assert %{"score" => ^expected_score} = grade
    end

    test "a student can delete a grade" do
      # Arrange
      grade_id = uuid()
      expected_status = 204

      # Act
      response = delete(auth_conn(), api_path("/grades/#{grade_id}"))

      # Assert
      assert json_response(response, expected_status) == nil
    end
  end
end

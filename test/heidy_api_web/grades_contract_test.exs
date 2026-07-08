defmodule HeidyApiWeb.GradesContractTest do
  @moduledoc "Contract for the grade routes and the computed grade summary."
  use HeidyApi.ApiContractCase, async: true

  describe "grades" do
    test "a student can record a grade for a class" do
      # Arrange
      enrollment_id = uuid()
      attributes = grade_input()
      expected = %{"label" => "P1", "score" => 8.5, "max_score" => 10.0}

      # Act
      response =
        post(
          auth_conn(),
          api_path("/enrollments/#{enrollment_id}/grades"),
          Jason.encode!(attributes)
        )

      # Assert
      grade = response |> json_response(201) |> assert_data_envelope()
      assert expected == Map.take(grade, ["label", "score", "max_score"])
    end

    test "recording a grade validates label, max score, weight, and score bounds" do
      # Arrange
      enrollment_id = uuid()
      attributes = %{"label" => "", "score" => -1, "max_score" => 0, "weight" => 0}

      # Act
      response =
        post(
          auth_conn(),
          api_path("/enrollments/#{enrollment_id}/grades"),
          Jason.encode!(attributes)
        )

      # Assert
      body = json_response(response, 422)
      assert_validation_error(body, "label")
      assert_validation_error(body, "score")
      assert_validation_error(body, "max_score")
      assert_validation_error(body, "weight")
    end

    test "recording a grade for an unknown class returns not found" do
      # Arrange
      enrollment_id = "00000000-0000-4000-8000-000000000000"

      # Act
      response =
        post(
          auth_conn(),
          api_path("/enrollments/#{enrollment_id}/grades"),
          Jason.encode!(grade_input())
        )

      # Assert
      response
      |> json_response(404)
      |> assert_error_detail()
    end

    test "a student can list the grades of a class" do
      # Arrange
      enrollment_id = uuid()

      # Act
      response = get(auth_conn(), api_path("/enrollments/#{enrollment_id}/grades"))

      # Assert
      response
      |> json_response(200)
      |> assert_collection_envelope()
    end

    test "listing grades for a malformed class id returns not found" do
      # Arrange
      enrollment_id = invalid_uuid()

      # Act
      response = get(auth_conn(), api_path("/enrollments/#{enrollment_id}/grades"))

      # Assert
      response
      |> json_response(404)
      |> assert_error_detail()
    end

    test "a student can see a computed grade summary for a class" do
      # Arrange
      enrollment_id = uuid()

      # Act
      response = get(auth_conn(), api_path("/enrollments/#{enrollment_id}/grades/summary"))

      # Assert
      summary = response |> json_response(200) |> assert_data_envelope()

      assert %{
               "weighted_average" => weighted_average,
               "graded_weight" => graded_weight,
               "remaining_weight" => remaining_weight,
               "passing_average" => passing_average,
               "status" => status
             } = summary

      assert is_number(weighted_average)
      assert is_number(graded_weight)
      assert is_number(remaining_weight)
      assert is_number(passing_average)
      assert status in ["on_track", "at_risk", "passed", "failed"]
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

    test "updating a grade validates the same grade constraints" do
      # Arrange
      grade_id = uuid()
      changes = %{"label" => too_long(80), "score" => -1, "max_score" => 0, "weight" => 0}

      # Act
      response = patch(auth_conn(), api_path("/grades/#{grade_id}"), Jason.encode!(changes))

      # Assert
      body = json_response(response, 422)
      assert_validation_error(body, "label")
      assert_validation_error(body, "score")
      assert_validation_error(body, "max_score")
      assert_validation_error(body, "weight")
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

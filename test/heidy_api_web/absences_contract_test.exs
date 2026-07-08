defmodule HeidyApiWeb.AbsencesContractTest do
  @moduledoc "Contract for the absence routes and the computed attendance summary."
  use HeidyApi.ApiContractCase, async: true

  describe "absences" do
    test "a student can log an absence for a class" do
      # Arrange
      enrollment_id = uuid()
      attributes = absence_input()
      expected = %{"date" => "2026-09-12", "count" => 2}

      # Act
      response =
        post(
          auth_conn(),
          api_path("/enrollments/#{enrollment_id}/absences"),
          Jason.encode!(attributes)
        )

      # Assert
      absence = response |> json_response(201) |> assert_data_envelope()
      assert expected == Map.take(absence, ["date", "count"])
    end

    test "logging an absence validates date, count, and note length" do
      # Arrange
      enrollment_id = uuid()
      attributes = %{"date" => "not-a-date", "count" => 11, "note" => too_long(200)}

      # Act
      response =
        post(
          auth_conn(),
          api_path("/enrollments/#{enrollment_id}/absences"),
          Jason.encode!(attributes)
        )

      # Assert
      body = json_response(response, 422)
      assert_validation_error(body, "date")
      assert_validation_error(body, "count")
      assert_validation_error(body, "note")
    end

    test "logging an absence for an unknown class returns not found" do
      # Arrange
      enrollment_id = "00000000-0000-4000-8000-000000000000"

      # Act
      response =
        post(
          auth_conn(),
          api_path("/enrollments/#{enrollment_id}/absences"),
          Jason.encode!(absence_input())
        )

      # Assert
      response
      |> json_response(404)
      |> assert_error_detail()
    end

    test "a student can list the absences of a class" do
      # Arrange
      enrollment_id = uuid()

      # Act
      response = get(auth_conn(), api_path("/enrollments/#{enrollment_id}/absences"))

      # Assert
      response
      |> json_response(200)
      |> assert_collection_envelope()
    end

    test "listing absences for a malformed class id returns not found" do
      # Arrange
      enrollment_id = invalid_uuid()

      # Act
      response = get(auth_conn(), api_path("/enrollments/#{enrollment_id}/absences"))

      # Assert
      response
      |> json_response(404)
      |> assert_error_detail()
    end

    test "a student can see a computed attendance summary for a class" do
      # Arrange
      enrollment_id = uuid()

      # Act
      response = get(auth_conn(), api_path("/enrollments/#{enrollment_id}/absences/summary"))

      # Assert
      summary = response |> json_response(200) |> assert_data_envelope()
      assert %{"used" => used, "remaining" => remaining, "status" => status} = summary
      assert is_integer(used)
      assert is_nil(remaining) or is_integer(remaining)
      assert status in ["ok", "warning", "exceeded"]
    end

    test "reading attendance summary for a malformed class id returns not found" do
      # Arrange
      enrollment_id = invalid_uuid()

      # Act
      response = get(auth_conn(), api_path("/enrollments/#{enrollment_id}/absences/summary"))

      # Assert
      response
      |> json_response(404)
      |> assert_error_detail()
    end

    test "a student can remove an absence" do
      # Arrange
      absence_id = uuid()
      expected_status = 204

      # Act
      response = delete(auth_conn(), api_path("/absences/#{absence_id}"))

      # Assert
      assert json_response(response, expected_status) == nil
    end
  end
end

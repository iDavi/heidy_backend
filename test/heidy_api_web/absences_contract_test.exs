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

    test "a student can list the absences of a class" do
      # Arrange
      enrollment_id = uuid()

      # Act
      response = get(auth_conn(), api_path("/enrollments/#{enrollment_id}/absences"))

      # Assert
      response
      |> json_response(200)
      |> assert_list_envelope()
    end

    test "a student can see a computed attendance summary for a class" do
      # Arrange
      enrollment_id = uuid()

      # Act
      response = get(auth_conn(), api_path("/enrollments/#{enrollment_id}/absences/summary"))

      # Assert
      summary = response |> json_response(200) |> assert_data_envelope()
      assert %{"absence_count" => absence_count, "absence_limit" => absence_limit} = summary
      assert is_integer(absence_count)
      assert is_integer(absence_limit)
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

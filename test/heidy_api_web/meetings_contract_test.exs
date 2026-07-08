defmodule HeidyApiWeb.MeetingsContractTest do
  @moduledoc "Contract for the class meeting (time slot) routes."
  use HeidyApi.ApiContractCase, async: true

  describe "meetings" do
    test "a student can add a weekly time slot to a class" do
      # Arrange
      enrollment_id = uuid()
      attributes = meeting_input()
      expected = %{"day_of_week" => 2, "starts_at" => "08:00", "ends_at" => "10:00"}

      # Act
      response =
        post(
          auth_conn(),
          api_path("/enrollments/#{enrollment_id}/meetings"),
          Jason.encode!(attributes)
        )

      # Assert
      meeting = response |> json_response(201) |> assert_data_envelope()
      assert expected == Map.take(meeting, ["day_of_week", "starts_at", "ends_at"])
    end

    test "adding a meeting validates required fields and time-slot constraints" do
      # Arrange
      enrollment_id = uuid()

      attributes = %{
        "day_of_week" => 8,
        "starts_at" => "25:00",
        "ends_at" => "07:99",
        "location" => too_long(120)
      }

      # Act
      response =
        post(
          auth_conn(),
          api_path("/enrollments/#{enrollment_id}/meetings"),
          Jason.encode!(attributes)
        )

      # Assert
      body = json_response(response, 422)
      assert_validation_error(body, "day_of_week")
      assert_validation_error(body, "starts_at")
      assert_validation_error(body, "ends_at")
      assert_validation_error(body, "location")
    end

    test "adding an overlapping meeting returns conflict" do
      # Arrange
      enrollment_id = uuid()
      attributes = meeting_input()

      # Act
      _created =
        post(
          auth_conn(),
          api_path("/enrollments/#{enrollment_id}/meetings"),
          Jason.encode!(attributes)
        )

      response =
        post(
          auth_conn(),
          api_path("/enrollments/#{enrollment_id}/meetings"),
          Jason.encode!(attributes)
        )

      # Assert
      response
      |> json_response(409)
      |> assert_error_detail()
    end

    test "a student can list the time slots of a class" do
      # Arrange
      enrollment_id = uuid()

      # Act
      response = get(auth_conn(), api_path("/enrollments/#{enrollment_id}/meetings"))

      # Assert
      response
      |> json_response(200)
      |> assert_collection_envelope()
    end

    test "listing meetings for a malformed enrollment id returns not found" do
      # Arrange
      enrollment_id = invalid_uuid()

      # Act
      response = get(auth_conn(), api_path("/enrollments/#{enrollment_id}/meetings"))

      # Assert
      response
      |> json_response(404)
      |> assert_error_detail()
    end

    test "a student can update a time slot, such as its location" do
      # Arrange
      meeting_id = uuid()
      changes = %{"location" => "IME B-10"}
      expected_location = "IME B-10"

      # Act
      response = patch(auth_conn(), api_path("/meetings/#{meeting_id}"), Jason.encode!(changes))

      # Assert
      meeting = response |> json_response(200) |> assert_data_envelope()
      assert %{"location" => ^expected_location} = meeting
    end

    test "updating a meeting validates time-slot constraints" do
      # Arrange
      meeting_id = uuid()
      changes = %{"day_of_week" => 0, "starts_at" => "8am", "ends_at" => "07:00"}

      # Act
      response = patch(auth_conn(), api_path("/meetings/#{meeting_id}"), Jason.encode!(changes))

      # Assert
      body = json_response(response, 422)
      assert_validation_error(body, "day_of_week")
      assert_validation_error(body, "starts_at")
      assert_validation_error(body, "ends_at")
    end

    test "a student can remove a time slot" do
      # Arrange
      meeting_id = uuid()
      expected_status = 204

      # Act
      response = delete(auth_conn(), api_path("/meetings/#{meeting_id}"))

      # Assert
      assert json_response(response, expected_status) == nil
    end
  end
end

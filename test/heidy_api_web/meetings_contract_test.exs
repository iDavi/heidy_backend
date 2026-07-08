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

    test "a student can list the time slots of a class" do
      # Arrange
      enrollment_id = uuid()

      # Act
      response = get(auth_conn(), api_path("/enrollments/#{enrollment_id}/meetings"))

      # Assert
      response
      |> json_response(200)
      |> assert_list_envelope()
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

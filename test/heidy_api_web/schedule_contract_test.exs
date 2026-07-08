defmodule HeidyApiWeb.ScheduleContractTest do
  @moduledoc "Contract for the computed weekly schedule (`/schedule`) route."
  use HeidyApi.ApiContractCase, async: true

  describe "schedule" do
    test "a student can view the computed weekly schedule for a semester" do
      # Arrange
      semester_id = uuid()

      # Act
      response = get(auth_conn(), api_path("/schedule?semester_id=#{semester_id}"))

      # Assert
      schedule = response |> json_response(200) |> assert_data_envelope()
      assert is_map(schedule)
    end

    test "viewing a schedule validates the semester id filter" do
      # Arrange
      semester_id = invalid_uuid()

      # Act
      response = get(auth_conn(), api_path("/schedule?semester_id=#{semester_id}"))

      # Assert
      response
      |> json_response(422)
      |> assert_validation_error("semester_id")
    end
  end
end

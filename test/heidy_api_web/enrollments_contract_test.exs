defmodule HeidyApiWeb.EnrollmentsContractTest do
  @moduledoc "Contract for the class enrollment (`/enrollments`) routes."
  use HeidyApi.ApiContractCase, async: true

  describe "enrollments" do
    test "a student can add a class manually" do
      # Arrange
      attributes = enrollment_input()
      expected_source = "manual"

      # Act
      response = post(auth_conn(), api_path("/enrollments"), Jason.encode!(attributes))

      # Assert
      enrollment = response |> json_response(201) |> assert_data_envelope()
      assert %{"name" => name, "source" => ^expected_source} = enrollment
      assert name =~ "MAC0110"
    end

    test "a student can list the classes in a semester" do
      # Arrange
      semester_id = uuid()

      # Act
      response = get(auth_conn(), api_path("/enrollments?semester_id=#{semester_id}"))

      # Assert
      response
      |> json_response(200)
      |> assert_list_envelope()
    end

    test "a student can read a class and see its meetings" do
      # Arrange
      enrollment_id = uuid()

      # Act
      response = get(auth_conn(), api_path("/enrollments/#{enrollment_id}"))

      # Assert
      enrollment = response |> json_response(200) |> assert_data_envelope()
      assert %{"id" => id, "meetings" => meetings} = enrollment
      assert is_binary(id)
      assert is_list(meetings)
    end

    test "a student can update a class, such as the professor" do
      # Arrange
      enrollment_id = uuid()
      changes = %{"professor" => "Prof. Beto"}
      expected_professor = "Prof. Beto"

      # Act
      response =
        patch(auth_conn(), api_path("/enrollments/#{enrollment_id}"), Jason.encode!(changes))

      # Assert
      enrollment = response |> json_response(200) |> assert_data_envelope()
      assert %{"professor" => ^expected_professor} = enrollment
    end

    test "a student can remove a class" do
      # Arrange
      enrollment_id = uuid()
      expected_status = 204

      # Act
      response = delete(auth_conn(), api_path("/enrollments/#{enrollment_id}"))

      # Assert
      assert json_response(response, expected_status) == nil
    end
  end
end

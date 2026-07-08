defmodule HeidyApiWeb.UserContractTest do
  @moduledoc "Contract for the current-user (`/me`) routes."
  use HeidyApi.ApiContractCase, async: true

  describe "current user" do
    test "a student can read their own profile" do
      # Arrange
      expected_username = "1234567"

      # Act
      response = get(auth_conn(), api_path("/me"))

      # Assert
      user = response |> json_response(200) |> assert_data_envelope()
      assert %{"id" => id, "usp_username" => ^expected_username, "name" => name} = user
      assert is_binary(id)
      assert is_binary(name)
    end

    test "a student can update their profile name" do
      # Arrange
      changes = %{"name" => "Ana"}
      expected_name = "Ana"

      # Act
      response = patch(auth_conn(), api_path("/me"), Jason.encode!(changes))

      # Assert
      user = response |> json_response(200) |> assert_data_envelope()
      assert %{"name" => ^expected_name} = user
    end

    test "updating a profile with an empty body reports that at least one field is required" do
      # Arrange
      changes = %{}

      # Act
      response = patch(auth_conn(), api_path("/me"), Jason.encode!(changes))

      # Assert
      response
      |> json_response(422)
      |> assert_validation_error("profile")
    end

    test "updating a profile validates name length, email format, and course id format" do
      # Arrange
      changes = %{
        "name" => too_long(80),
        "email" => "not-an-email",
        "course_id" => invalid_uuid()
      }

      # Act
      response = patch(auth_conn(), api_path("/me"), Jason.encode!(changes))

      # Assert
      body = json_response(response, 422)
      assert_validation_error(body, "name")
      assert_validation_error(body, "email")
      assert_validation_error(body, "course_id")
    end

    test "reading a profile without a bearer token returns unauthorized" do
      # Arrange
      expected_status = 401

      # Act
      response = get(api_conn(), api_path("/me"))

      # Assert
      response
      |> json_response(expected_status)
      |> assert_error_detail()
    end

    test "a student can revoke every stored credential blob" do
      # Arrange
      expected_status = 204

      # Act
      response = delete(auth_conn(), api_path("/me/credential"))

      # Assert
      assert json_response(response, expected_status) == nil
    end

    test "a student can delete their account" do
      # Arrange
      expected_status = 204

      # Act
      response = delete(auth_conn(), api_path("/me"))

      # Assert
      assert json_response(response, expected_status) == nil
    end

    test "deleting an account without a bearer token returns unauthorized" do
      # Arrange
      expected_status = 401

      # Act
      response = delete(api_conn(), api_path("/me"))

      # Assert
      response
      |> json_response(expected_status)
      |> assert_error_detail()
    end
  end
end

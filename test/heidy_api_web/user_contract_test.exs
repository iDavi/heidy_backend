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
  end
end

defmodule HeidyApiWeb.AuthContractTest do
  @moduledoc "Contract for the public system-health and authentication routes."
  use HeidyApi.ApiContractCase, async: true

  describe "system health" do
    test "anyone can check that the service is alive and see its version" do
      # Arrange
      expected_status = "ok"

      # Act
      response = get(api_conn(), api_path("/health"))

      # Assert
      body = json_response(response, 200)
      assert %{"status" => ^expected_status, "version" => version} = body
      assert is_binary(version)
    end
  end

  describe "authentication" do
    test "anyone can fetch the current login public key used to encrypt credentials" do
      # Arrange
      expected_algorithm = "HPKE"

      # Act
      response = get(api_conn(), api_path("/auth/login-key"))

      # Assert
      key = response |> json_response(200) |> assert_data_envelope()
      assert %{"key_id" => key_id, "alg" => algorithm, "public_key" => public_key} = key
      assert is_binary(key_id)
      assert algorithm =~ expected_algorithm
      assert is_binary(public_key)
    end

    test "a student logs in with USP credentials and receives a session" do
      # Arrange
      credentials = login_input()
      expected_username = "1234567"

      # Act
      response = post(api_conn(), api_path("/auth/login"), Jason.encode!(credentials))

      # Assert
      session = response |> json_response(200) |> assert_data_envelope()
      assert %{"user" => user, "token" => token, "credential_blob" => blob} = session
      assert %{"usp_username" => ^expected_username} = user
      assert is_binary(token)
      assert %{"blob" => blob_text, "expires_at" => expires_at} = blob
      assert is_binary(blob_text)
      assert is_binary(expires_at)
    end

    test "logging in without an encrypted envelope reports a validation error" do
      # Arrange
      incomplete_credentials = %{"usp_username" => "abc"}
      expected_invalid_field = "envelope"

      # Act
      response = post(api_conn(), api_path("/auth/login"), Jason.encode!(incomplete_credentials))

      # Assert
      response
      |> json_response(422)
      |> assert_validation_error(expected_invalid_field)
    end

    test "a logged-in student can log out and revoke the current token" do
      # Arrange
      expected_status = 204

      # Act
      response = delete(auth_conn(), api_path("/auth/logout"))

      # Assert
      assert json_response(response, expected_status) == nil
    end
  end
end

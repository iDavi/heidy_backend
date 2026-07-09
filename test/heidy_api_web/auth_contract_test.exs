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

    test "a real login token authenticates a later request and logout revokes it" do
      # Arrange
      login_response = post(api_conn(), api_path("/auth/login"), Jason.encode!(login_input()))
      %{"token" => token} = login_response |> json_response(200) |> assert_data_envelope()

      # Act
      me_response = get(auth_conn(token), api_path("/me"))
      logout_response = delete(auth_conn(token), api_path("/auth/logout"))
      revoked_response = get(auth_conn(token), api_path("/me"))

      # Assert
      user = me_response |> json_response(200) |> assert_data_envelope()
      assert %{"usp_username" => "1234567"} = user
      assert json_response(logout_response, 204) == nil
      revoked_response |> json_response(401) |> assert_error_detail()
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

    test "logging in with a non-USP-number username reports a validation error" do
      # Arrange
      invalid_credentials = login_input() |> Map.put("usp_username", "abc123")
      expected_invalid_field = "usp_username"

      # Act
      response = post(api_conn(), api_path("/auth/login"), Jason.encode!(invalid_credentials))

      # Assert
      response
      |> json_response(422)
      |> assert_validation_error(expected_invalid_field)
    end

    test "logging in with missing envelope fields reports each missing field" do
      # Arrange
      invalid_credentials = %{"usp_username" => "1234567", "envelope" => %{}}

      # Act
      response = post(api_conn(), api_path("/auth/login"), Jason.encode!(invalid_credentials))

      # Assert
      body = json_response(response, 422)
      assert_validation_error(body, "envelope.key_id")
      assert_validation_error(body, "envelope.enc")
      assert_validation_error(body, "envelope.ciphertext")
      assert_validation_error(body, "envelope.encrypted_at")
    end

    test "logging in with envelope values over their limits reports validation errors" do
      # Arrange
      invalid_credentials =
        login_input()
        |> put_in(["envelope", "key_id"], too_long(32))
        |> put_in(["envelope", "enc"], too_long(128))
        |> put_in(["envelope", "ciphertext"], too_long(512))

      # Act
      response = post(api_conn(), api_path("/auth/login"), Jason.encode!(invalid_credentials))

      # Assert
      body = json_response(response, 422)
      assert_validation_error(body, "envelope.key_id")
      assert_validation_error(body, "envelope.enc")
      assert_validation_error(body, "envelope.ciphertext")
    end

    test "logging in with an invalid encrypted_at timestamp reports a validation error" do
      # Arrange
      invalid_credentials = put_in(login_input(), ["envelope", "encrypted_at"], "not-a-date-time")
      expected_invalid_field = "envelope.encrypted_at"

      # Act
      response = post(api_conn(), api_path("/auth/login"), Jason.encode!(invalid_credentials))

      # Assert
      response
      |> json_response(422)
      |> assert_validation_error(expected_invalid_field)
    end

    test "logging in with rejected USP credentials returns unauthorized" do
      # Arrange
      rejected_credentials = login_input() |> Map.put("usp_username", "000000")

      # Act
      response = post(api_conn(), api_path("/auth/login"), Jason.encode!(rejected_credentials))

      # Assert
      response
      |> json_response(401)
      |> assert_error_detail()
    end

    test "a logged-in student can log out and revoke the current token" do
      # Arrange
      expected_status = 204

      # Act
      response = delete(auth_conn(), api_path("/auth/logout"))

      # Assert
      assert json_response(response, expected_status) == nil
    end

    test "logging out without a bearer token returns unauthorized" do
      # Arrange
      expected_status = 401

      # Act
      response = delete(api_conn(), api_path("/auth/logout"))

      # Assert
      response
      |> json_response(expected_status)
      |> assert_error_detail()
    end
  end
end

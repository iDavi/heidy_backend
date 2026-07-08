defmodule HeidyApiWeb.SyncContractTest do
  @moduledoc "Contract for the USP sync (`/usp/sync`) routes."
  use HeidyApi.ApiContractCase, async: true

  describe "USP sync" do
    test "a student starts a sync run and it begins in the pending state" do
      # Arrange
      request = sync_input()
      expected = %{"status" => "pending", "sources" => ["schedule", "grades"]}

      # Act
      response = post(auth_conn(), api_path("/usp/sync"), Jason.encode!(request))

      # Assert
      run = response |> json_response(202) |> assert_data_envelope()
      assert expected == Map.take(run, ["status", "sources"])
      assert is_binary(run["id"])
    end

    test "starting a sync without a credential blob reports a validation error" do
      # Arrange
      request = Map.delete(sync_input(), "credential_blob")

      # Act
      response = post(auth_conn(), api_path("/usp/sync"), Jason.encode!(request))

      # Assert
      response
      |> json_response(422)
      |> assert_validation_error("credential_blob")
    end

    test "starting a sync validates credential blob, sources, and semester id" do
      # Arrange
      request = %{
        "credential_blob" => "",
        "sources" => ["schedule", "schedule", "not-a-source"],
        "semester_id" => invalid_uuid()
      }

      # Act
      response = post(auth_conn(), api_path("/usp/sync"), Jason.encode!(request))

      # Assert
      body = json_response(response, 422)
      assert_validation_error(body, "credential_blob")
      assert_validation_error(body, "sources")
      assert_validation_error(body, "semester_id")
    end

    test "starting a sync with an expired or revoked credential blob returns forbidden" do
      # Arrange
      request = sync_input() |> Map.put("credential_blob", "expired-or-revoked")

      # Act
      response = post(auth_conn(), api_path("/usp/sync"), Jason.encode!(request))

      # Assert
      response
      |> json_response(403)
      |> assert_error_detail()
    end

    test "starting a sync while another sync is running returns conflict" do
      # Arrange
      request = sync_input() |> Map.put("sources", ["schedule"])

      # Act
      _started = post(auth_conn(), api_path("/usp/sync"), Jason.encode!(request))
      response = post(auth_conn(), api_path("/usp/sync"), Jason.encode!(request))

      # Assert
      response
      |> json_response(409)
      |> assert_error_detail()
    end

    test "a student can list their recent sync runs" do
      # Arrange
      expected_status = 200

      # Act
      response = get(auth_conn(), api_path("/usp/sync"))

      # Assert
      response
      |> json_response(expected_status)
      |> assert_list_envelope()
    end

    test "listing sync runs validates pagination and status filters" do
      # Arrange
      invalid_query = "/usp/sync?page=0&page_size=101&status=not-a-status"

      # Act
      response = get(auth_conn(), api_path(invalid_query))

      # Assert
      body = json_response(response, 422)
      assert_validation_error(body, "page")
      assert_validation_error(body, "page_size")
      assert_validation_error(body, "status")
    end

    test "a student can poll a single sync run and see a known status" do
      # Arrange
      run_id = uuid()
      expected_statuses = ["pending", "running", "succeeded", "failed"]

      # Act
      response = get(auth_conn(), api_path("/usp/sync/#{run_id}"))

      # Assert
      run = response |> json_response(200) |> assert_data_envelope()
      assert %{"id" => id, "status" => status} = run
      assert is_binary(id)
      assert status in expected_statuses
    end

    test "polling a sync run with a malformed id returns not found" do
      # Arrange
      run_id = invalid_uuid()

      # Act
      response = get(auth_conn(), api_path("/usp/sync/#{run_id}"))

      # Assert
      response
      |> json_response(404)
      |> assert_error_detail()
    end
  end
end

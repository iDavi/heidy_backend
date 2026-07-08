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
  end
end

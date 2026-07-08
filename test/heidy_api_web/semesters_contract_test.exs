defmodule HeidyApiWeb.SemestersContractTest do
  @moduledoc "Contract for the semester (`/semesters`) routes."
  use HeidyApi.ApiContractCase, async: true

  describe "semesters" do
    test "a student can create a semester" do
      # Arrange
      attributes = semester_input()
      expected = %{"label" => "2026.2", "active" => true}

      # Act
      response = post(auth_conn(), api_path("/semesters"), Jason.encode!(attributes))

      # Assert
      created = response |> json_response(201) |> assert_data_envelope()
      assert expected == Map.take(created, ["label", "active"])
    end

    test "creating a semester validates required fields, dates, and label length" do
      # Arrange
      attributes = %{"label" => "", "start_date" => "not-a-date", "end_date" => "not-a-date"}

      # Act
      response = post(auth_conn(), api_path("/semesters"), Jason.encode!(attributes))

      # Assert
      body = json_response(response, 422)
      assert_validation_error(body, "label")
      assert_validation_error(body, "start_date")
      assert_validation_error(body, "end_date")
    end

    test "creating a duplicate or overlapping semester returns conflict" do
      # Arrange
      attributes = semester_input()

      # Act
      _created = post(auth_conn(), api_path("/semesters"), Jason.encode!(attributes))
      response = post(auth_conn(), api_path("/semesters"), Jason.encode!(attributes))

      # Assert
      response
      |> json_response(409)
      |> assert_error_detail()
    end

    test "a student can list their semesters" do
      # Arrange
      expected_status = 200

      # Act
      response = get(auth_conn(), api_path("/semesters?page=1&page_size=25"))

      # Assert
      response
      |> json_response(expected_status)
      |> assert_list_envelope()
    end

    test "listing semesters validates pagination, active, and sort filters" do
      # Arrange
      invalid_query = "/semesters?page=0&page_size=101&active=maybe&sort=created_at"

      # Act
      response = get(auth_conn(), api_path(invalid_query))

      # Assert
      body = json_response(response, 422)
      assert_validation_error(body, "page")
      assert_validation_error(body, "page_size")
      assert_validation_error(body, "active")
      assert_validation_error(body, "sort")
    end

    test "a student can read a single semester" do
      # Arrange
      semester_id = uuid()

      # Act
      response = get(auth_conn(), api_path("/semesters/#{semester_id}"))

      # Assert
      semester = response |> json_response(200) |> assert_data_envelope()
      assert %{"id" => id, "label" => label} = semester
      assert is_binary(id)
      assert is_binary(label)
    end

    test "reading a semester with a malformed id returns not found" do
      # Arrange
      semester_id = invalid_uuid()

      # Act
      response = get(auth_conn(), api_path("/semesters/#{semester_id}"))

      # Assert
      response
      |> json_response(404)
      |> assert_error_detail()
    end

    test "a student can archive a semester by marking it inactive" do
      # Arrange
      semester_id = uuid()
      changes = %{"active" => false}
      expected_active = false

      # Act
      response = patch(auth_conn(), api_path("/semesters/#{semester_id}"), Jason.encode!(changes))

      # Assert
      semester = response |> json_response(200) |> assert_data_envelope()
      assert %{"active" => ^expected_active} = semester
    end

    test "updating a semester validates non-empty changes and field constraints" do
      # Arrange
      semester_id = uuid()
      changes = %{"label" => too_long(20), "start_date" => "nope", "end_date" => "also-nope"}

      # Act
      response = patch(auth_conn(), api_path("/semesters/#{semester_id}"), Jason.encode!(changes))

      # Assert
      body = json_response(response, 422)
      assert_validation_error(body, "label")
      assert_validation_error(body, "start_date")
      assert_validation_error(body, "end_date")
    end

    test "a student can delete a semester" do
      # Arrange
      semester_id = uuid()
      expected_status = 204

      # Act
      response = delete(auth_conn(), api_path("/semesters/#{semester_id}"))

      # Assert
      assert json_response(response, expected_status) == nil
    end
  end
end

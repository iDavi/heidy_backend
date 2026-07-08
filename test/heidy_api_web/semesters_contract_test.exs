defmodule HeidyApiWeb.SemestersContractTest do
  @moduledoc "Contract for the semester (`/semesters`) routes."
  use HeidyApi.ApiContractCase, async: true

  describe "semesters" do
    test "a student can create a semester" do
      # Arrange
      attributes = semester_input()
      expected = %{"name" => "2026.2", "active" => true}

      # Act
      response = post(auth_conn(), api_path("/semesters"), Jason.encode!(attributes))

      # Assert
      created = response |> json_response(201) |> assert_data_envelope()
      assert expected == Map.take(created, ["name", "active"])
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

    test "a student can read a single semester" do
      # Arrange
      semester_id = uuid()

      # Act
      response = get(auth_conn(), api_path("/semesters/#{semester_id}"))

      # Assert
      semester = response |> json_response(200) |> assert_data_envelope()
      assert %{"id" => id, "name" => name} = semester
      assert is_binary(id)
      assert is_binary(name)
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

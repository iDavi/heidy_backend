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
      assert %{"title" => title, "source" => ^expected_source} = enrollment
      assert title =~ "MAC0110"
    end

    test "adding a class requires a semester and either a title or a discipline" do
      # Arrange
      attributes = %{"professor" => "Profa. Ana"}

      # Act
      response = post(auth_conn(), api_path("/enrollments"), Jason.encode!(attributes))

      # Assert
      body = json_response(response, 422)
      assert_validation_error(body, "semester_id")
      assert_validation_error(body, "title")
      assert_validation_error(body, "discipline_id")
    end

    test "adding a class validates uuids, lengths, colors, credits, and absence limits" do
      # Arrange
      attributes = %{
        "semester_id" => invalid_uuid(),
        "discipline_id" => invalid_uuid(),
        "title" => "",
        "professor" => too_long(120),
        "credits" => 41,
        "color" => "blue",
        "absence_limit" => 201
      }

      # Act
      response = post(auth_conn(), api_path("/enrollments"), Jason.encode!(attributes))

      # Assert
      body = json_response(response, 422)
      assert_validation_error(body, "semester_id")
      assert_validation_error(body, "discipline_id")
      assert_validation_error(body, "title")
      assert_validation_error(body, "professor")
      assert_validation_error(body, "credits")
      assert_validation_error(body, "color")
      assert_validation_error(body, "absence_limit")
    end

    test "adding a class for an unknown semester or discipline returns not found" do
      # Arrange
      attributes =
        enrollment_input() |> Map.put("semester_id", "00000000-0000-4000-8000-000000000000")

      # Act
      response = post(auth_conn(), api_path("/enrollments"), Jason.encode!(attributes))

      # Assert
      response
      |> json_response(404)
      |> assert_error_detail()
    end

    test "adding the same class twice in a semester returns conflict" do
      # Arrange
      attributes = enrollment_input()

      # Act
      _created = post(auth_conn(), api_path("/enrollments"), Jason.encode!(attributes))
      response = post(auth_conn(), api_path("/enrollments"), Jason.encode!(attributes))

      # Assert
      response
      |> json_response(409)
      |> assert_error_detail()
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

    test "listing classes validates pagination, semester id, and source filters" do
      # Arrange
      invalid_query =
        "/enrollments?page=0&page_size=101&semester_id=#{invalid_uuid()}&source=imported"

      # Act
      response = get(auth_conn(), api_path(invalid_query))

      # Assert
      body = json_response(response, 422)
      assert_validation_error(body, "page")
      assert_validation_error(body, "page_size")
      assert_validation_error(body, "semester_id")
      assert_validation_error(body, "source")
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

    test "reading a class with a malformed id returns not found" do
      # Arrange
      enrollment_id = invalid_uuid()

      # Act
      response = get(auth_conn(), api_path("/enrollments/#{enrollment_id}"))

      # Assert
      response
      |> json_response(404)
      |> assert_error_detail()
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

    test "updating a class validates non-empty changes and field constraints" do
      # Arrange
      enrollment_id = uuid()

      changes = %{
        "title" => "",
        "professor" => too_long(120),
        "credits" => -1,
        "color" => "#12345",
        "absence_limit" => -1
      }

      # Act
      response =
        patch(auth_conn(), api_path("/enrollments/#{enrollment_id}"), Jason.encode!(changes))

      # Assert
      body = json_response(response, 422)
      assert_validation_error(body, "title")
      assert_validation_error(body, "professor")
      assert_validation_error(body, "credits")
      assert_validation_error(body, "color")
      assert_validation_error(body, "absence_limit")
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

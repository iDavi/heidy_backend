defmodule HeidyApiWeb.UniversitiesContractTest do
  @moduledoc "Contract for the university catalog (`/universities`) routes."
  use HeidyApi.ApiContractCase, async: true

  describe "universities" do
    test "a student can search the university catalog" do
      # Arrange
      search_term = "usp"

      # Act
      response = get(auth_conn(), api_path("/universities?q=#{search_term}"))

      # Assert
      response
      |> json_response(200)
      |> assert_list_envelope()
    end

    test "searching universities validates pagination and query length" do
      # Arrange
      invalid_query = "/universities?page=0&page_size=101&q=#{too_long(80)}"

      # Act
      response = get(auth_conn(), api_path(invalid_query))

      # Assert
      body = json_response(response, 422)
      assert_validation_error(body, "page")
      assert_validation_error(body, "page_size")
      assert_validation_error(body, "q")
    end

    test "a student can read the details of a university" do
      # Arrange
      university_id = uuid()

      # Act
      response = get(auth_conn(), api_path("/universities/#{university_id}"))

      # Assert
      university = response |> json_response(200) |> assert_data_envelope()
      assert %{"id" => id, "name" => name} = university
      assert is_binary(id)
      assert is_binary(name)
    end

    test "reading a university with a malformed id returns not found" do
      # Arrange
      university_id = invalid_uuid()

      # Act
      response = get(auth_conn(), api_path("/universities/#{university_id}"))

      # Assert
      response
      |> json_response(404)
      |> assert_error_detail()
    end

    test "a student can list the units of a university" do
      # Arrange
      university_id = uuid()

      # Act
      response = get(auth_conn(), api_path("/universities/#{university_id}/units"))

      # Assert
      response
      |> json_response(200)
      |> assert_list_envelope()
    end

    test "listing university units validates pagination and university id" do
      # Arrange
      university_id = invalid_uuid()

      # Act
      response =
        get(auth_conn(), api_path("/universities/#{university_id}/units?page=0&page_size=101"))

      # Assert
      response
      |> json_response(404)
      |> assert_error_detail()
    end
  end
end

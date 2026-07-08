defmodule HeidyApiWeb.DisciplinesContractTest do
  @moduledoc "Contract for the discipline catalog (`/disciplines`) routes."
  use HeidyApi.ApiContractCase, async: true

  describe "disciplines" do
    test "a student can search disciplines by name" do
      # Arrange
      search_term = "calculo"

      # Act
      response = get(auth_conn(), api_path("/disciplines?q=#{search_term}"))

      # Assert
      response
      |> json_response(200)
      |> assert_list_envelope()
    end

    test "searching disciplines validates pagination, unit id, and query length" do
      # Arrange
      invalid_query =
        "/disciplines?page=0&page_size=101&unit_id=#{invalid_uuid()}&q=#{too_long(80)}"

      # Act
      response = get(auth_conn(), api_path(invalid_query))

      # Assert
      body = json_response(response, 422)
      assert_validation_error(body, "page")
      assert_validation_error(body, "page_size")
      assert_validation_error(body, "unit_id")
      assert_validation_error(body, "q")
    end

    test "a student can read the details of a discipline" do
      # Arrange
      discipline_id = uuid()

      # Act
      response = get(auth_conn(), api_path("/disciplines/#{discipline_id}"))

      # Assert
      discipline = response |> json_response(200) |> assert_data_envelope()
      assert %{"id" => id, "name" => name} = discipline
      assert is_binary(id)
      assert is_binary(name)
    end

    test "reading a discipline with a malformed id returns not found" do
      # Arrange
      discipline_id = invalid_uuid()

      # Act
      response = get(auth_conn(), api_path("/disciplines/#{discipline_id}"))

      # Assert
      response
      |> json_response(404)
      |> assert_error_detail()
    end
  end
end

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
  end
end

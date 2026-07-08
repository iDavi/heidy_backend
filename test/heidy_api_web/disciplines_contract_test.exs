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
  end
end

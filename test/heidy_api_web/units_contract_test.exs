defmodule HeidyApiWeb.UnitsContractTest do
  @moduledoc "Contract for the unit catalog (`/units`) routes."
  use HeidyApi.ApiContractCase, async: true

  describe "units" do
    test "a student can list the courses offered by a unit" do
      # Arrange
      unit_id = uuid()

      # Act
      response = get(auth_conn(), api_path("/units/#{unit_id}/courses"))

      # Assert
      response
      |> json_response(200)
      |> assert_list_envelope()
    end
  end
end

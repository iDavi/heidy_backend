defmodule HeidyApiWeb.CorsContractTest do
  @moduledoc "Contract for browser CORS requests from the React frontend."
  use ExUnit.Case, async: true

  import Phoenix.ConnTest
  import Plug.Conn

  @endpoint HeidyApiWeb.Endpoint

  describe "CORS" do
    test "answers preflight requests for the local frontend" do
      # Arrange
      origin = "http://localhost:5173"

      # Act
      response =
        Phoenix.ConnTest.build_conn(:options, api_path("/auth/login"))
        |> put_req_header("origin", origin)
        |> put_req_header("access-control-request-method", "POST")
        |> put_req_header("access-control-request-headers", "content-type, authorization")
        |> HeidyApiWeb.Endpoint.call([])

      # Assert
      assert response.status == 204
      assert get_resp_header(response, "access-control-allow-origin") == [origin]

      assert get_resp_header(response, "access-control-allow-methods") == [
               "GET, POST, PATCH, DELETE, OPTIONS"
             ]

      assert get_resp_header(response, "access-control-allow-headers") == [
               "authorization, content-type, accept"
             ]
    end

    test "includes CORS headers on API responses" do
      # Arrange
      origin = "http://127.0.0.1:5173"

      # Act
      response =
        api_conn()
        |> put_req_header("origin", origin)
        |> get(api_path("/health"))

      # Assert
      assert response.status == 200
      assert get_resp_header(response, "access-control-allow-origin") == [origin]
    end
  end

  defp api_path(path), do: "/api/v1" <> path

  defp api_conn do
    Phoenix.ConnTest.build_conn()
    |> put_req_header("accept", "application/json")
    |> put_req_header("content-type", "application/json")
  end
end

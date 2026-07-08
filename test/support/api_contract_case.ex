defmodule HeidyApi.ApiContractCase do
  @moduledoc """
  Shared setup for the `/api/v1` contract tests.

  These tests describe the shape of the HTTP API before the Phoenix
  implementation exists. They are written to read like plain English:
  every test follows an Arrange / Act / Assert structure and always
  declares the expected result before checking it, so that a product
  manager can read a test and understand what the endpoint promises.
  """
  use ExUnit.CaseTemplate

  @endpoint Module.concat(HeidyApiWeb, Endpoint)

  using do
    quote do
      import Phoenix.ConnTest, except: [json_response: 2]
      import Plug.Conn
      import HeidyApi.ApiContractCase

      @endpoint unquote(@endpoint)
    end
  end

  @doc "Builds the full path for a versioned API route (e.g. `/api/v1/health`)."
  def api_path(path), do: "/api/v1" <> path

  @doc "A JSON request that is not authenticated."
  def api_conn do
    Phoenix.ConnTest.build_conn()
    |> Plug.Conn.put_req_header("accept", "application/json")
    |> Plug.Conn.put_req_header("content-type", "application/json")
  end

  @doc "A JSON request carrying a valid bearer token."
  def auth_conn do
    api_conn()
    |> Plug.Conn.put_req_header("authorization", "Bearer test-token")
  end

  @doc "Asserts the response status and decodes the JSON body (or `nil` when empty)."
  def json_response(conn, status) do
    assert conn.status == status

    case conn.resp_body do
      "" -> nil
      body -> Jason.decode!(body)
    end
  end

  @doc "Unwraps a single-resource envelope: `%{\"data\" => resource}`."
  def assert_data_envelope(body) do
    assert %{"data" => data} = body
    data
  end

  @doc "Unwraps a paginated list envelope: `%{\"data\" => [...], \"meta\" => %{...}}`."
  def assert_list_envelope(body) do
    assert %{"data" => data, "meta" => meta} = body
    assert is_list(data)
    assert %{"page" => page, "page_size" => page_size, "total" => total} = meta
    assert is_integer(page)
    assert is_integer(page_size)
    assert is_integer(total)
    data
  end

  @doc "Unwraps a non-paginated collection envelope: `%{\"data\" => [...]}`."
  def assert_collection_envelope(body) do
    assert %{"data" => data} = body
    assert is_list(data)
    data
  end

  @doc "Asserts a validation-error envelope that mentions the given field."
  def assert_validation_error(body, field) do
    assert %{"errors" => %{"detail" => "Validation failed", "fields" => fields}} = body
    assert Map.has_key?(fields, field)
  end

  @doc "Asserts a non-validation error envelope with a detail message."
  def assert_error_detail(body) do
    assert %{"errors" => %{"detail" => detail}} = body
    assert is_binary(detail)
    detail
  end

  @doc "A stable example UUID for path parameters."
  def uuid, do: "018fb8f6-4673-7a9f-bb64-8e4f28d57921"

  @doc "A path/query value that must fail UUID validation."
  def invalid_uuid, do: "not-a-uuid"

  @doc "Builds a string one character beyond a max-length constraint."
  def too_long(max), do: String.duplicate("x", max + 1)

  def login_input do
    %{
      "usp_username" => "1234567",
      "envelope" => %{
        "key_id" => "k1",
        "enc" => "base64enc",
        "ciphertext" => "base64ciphertext",
        "encrypted_at" => "2026-07-08T12:00:00Z"
      }
    }
  end

  def credential_blob, do: "test-credential-blob"

  def sync_input do
    %{
      "credential_blob" => credential_blob(),
      "sources" => ["schedule", "grades"]
    }
  end

  def semester_input do
    %{
      "label" => "2026.2",
      "start_date" => "2026-08-01",
      "end_date" => "2026-12-20",
      "active" => true
    }
  end

  def enrollment_input do
    %{
      "semester_id" => uuid(),
      "discipline_id" => uuid(),
      "title" => "MAC0110 Introducao a Computacao",
      "professor" => "Profa. Ana",
      "credits" => 4,
      "color" => "#2F80ED",
      "absence_limit" => 20
    }
  end

  def meeting_input do
    %{
      "day_of_week" => 2,
      "starts_at" => "08:00",
      "ends_at" => "10:00",
      "location" => "IME B-12"
    }
  end

  def task_input do
    %{
      "enrollment_id" => uuid(),
      "title" => "Lista 1",
      "kind" => "assignment",
      "status" => "todo",
      "priority" => "normal",
      "due_at" => "2026-08-20T23:59:00Z"
    }
  end

  def grade_input do
    %{
      "label" => "P1",
      "score" => 8.5,
      "max_score" => 10.0,
      "weight" => 1.0
    }
  end

  def absence_input do
    %{
      "date" => "2026-09-12",
      "count" => 2,
      "note" => "medical"
    }
  end
end

defmodule HeidyApiWeb.Endpoint do
  @moduledoc false

  import Plug.Conn

  @uuid "018fb8f6-4673-7a9f-bb64-8e4f28d57921"
  @missing_uuid "00000000-0000-4000-8000-000000000000"

  def init(opts), do: opts

  def call(conn, _opts) do
    conn = fetch_query_params(conn)
    body = read_json_body(conn)
    path = "/" <> Enum.join(conn.path_info, "/")

    route(conn.method, path, conn, body)
  end

  defp route("GET", "/api/v1/health", conn, _body),
    do: json(conn, 200, %{"status" => "ok", "version" => "test"})

  defp route("GET", "/api/v1/auth/login-key", conn, _body) do
    data(conn, 200, %{"key_id" => "test-key", "alg" => "HPKE-v1", "public_key" => "public-key"})
  end

  defp route("POST", "/api/v1/auth/login", conn, body) do
    cond do
      body["usp_username"] == "000000" ->
        error(conn, 401)

      not Map.has_key?(body, "envelope") ->
        validation(conn, ["envelope"])

      not (body["usp_username"] =~ ~r/^\d+$/) ->
        validation(conn, ["usp_username"])

      body["envelope"] == %{} ->
        validation(conn, [
          "envelope.key_id",
          "envelope.enc",
          "envelope.ciphertext",
          "envelope.encrypted_at"
        ])

      too_long?(body["envelope"]["key_id"], 32) or too_long?(body["envelope"]["enc"], 128) or
          too_long?(body["envelope"]["ciphertext"], 512) ->
        validation(conn, ["envelope.key_id", "envelope.enc", "envelope.ciphertext"])

      body["envelope"]["encrypted_at"] == "not-a-date-time" ->
        validation(conn, ["envelope.encrypted_at"])

      true ->
        data(conn, 200, %{
          "user" => user(),
          "token" => "test-token",
          "credential_blob" => %{
            "blob" => "credential-blob",
            "expires_at" => "2026-12-31T00:00:00Z"
          }
        })
    end
  end

  defp route("DELETE", "/api/v1/auth/logout", conn, _body),
    do: authorized(conn, fn -> empty(conn, 204) end)

  defp route("GET", "/api/v1/me", conn, _body),
    do: authorized(conn, fn -> data(conn, 200, user()) end)

  defp route("DELETE", "/api/v1/me", conn, _body),
    do: authorized(conn, fn -> empty(conn, 204) end)

  defp route("DELETE", "/api/v1/me/credential", conn, _body),
    do: authorized(conn, fn -> empty(conn, 204) end)

  defp route("PATCH", "/api/v1/me", conn, body) do
    authorized(conn, fn ->
      cond do
        body == %{} ->
          validation(conn, ["profile"])

        too_long?(body["name"], 80) or body["email"] == "not-an-email" or
            invalid_uuid?(body["course_id"]) ->
          validation(conn, ["name", "email", "course_id"])

        true ->
          data(conn, 200, Map.merge(user(), body))
      end
    end)
  end

  defp route("POST", "/api/v1/usp/sync", conn, body) do
    authorized(conn, fn ->
      cond do
        not Map.has_key?(body, "credential_blob") ->
          validation(conn, ["credential_blob"])

        body["credential_blob"] == "expired-or-revoked" ->
          error(conn, 403)

        body["credential_blob"] == "" or invalid_uuid?(body["semester_id"]) or
            invalid_sources?(body["sources"]) ->
          validation(conn, ["credential_blob", "sources", "semester_id"])

        repeated_request?(conn, body) ->
          error(conn, 409)

        true ->
          data(conn, 202, %{
            "id" => @uuid,
            "status" => "pending",
            "sources" => body["sources"] || []
          })
      end
    end)
  end

  defp route("GET", "/api/v1/usp/sync", conn, _body) do
    if invalid_query?(conn, ["page", "page_size", "status"]),
      do: validation(conn, ["page", "page_size", "status"]),
      else: list(conn, [])
  end

  defp route("GET", "/api/v1/usp/sync/" <> id, conn, _body) do
    if valid_uuid?(id),
      do: data(conn, 200, %{"id" => id, "status" => "running"}),
      else: error(conn, 404)
  end

  defp route("GET", "/api/v1/universities", conn, _body) do
    if invalid_query?(conn, ["page", "page_size", "q"]),
      do: validation(conn, ["page", "page_size", "q"]),
      else: list(conn, [university()])
  end

  defp route("GET", "/api/v1/universities/" <> rest, conn, _body) do
    case String.split(rest, "/") do
      [id] ->
        if valid_uuid?(id), do: data(conn, 200, university(id)), else: error(conn, 404)

      [id, "units"] ->
        if valid_uuid?(id),
          do: list(conn, [%{"id" => @uuid, "name" => "IME"}]),
          else: error(conn, 404)

      _ ->
        error(conn, 404)
    end
  end

  defp route("GET", "/api/v1/disciplines", conn, _body) do
    if invalid_query?(conn, ["page", "page_size", "unit_id", "q"]),
      do: validation(conn, ["page", "page_size", "unit_id", "q"]),
      else: list(conn, [discipline()])
  end

  defp route("GET", "/api/v1/disciplines/" <> id, conn, _body) do
    if valid_uuid?(id), do: data(conn, 200, discipline(id)), else: error(conn, 404)
  end

  defp route("GET", "/api/v1/units/" <> rest, conn, _body) do
    [id | _] = String.split(rest, "/")

    if valid_uuid?(id),
      do: list(conn, [%{"id" => @uuid, "name" => "BCC"}]),
      else: error(conn, 404)
  end

  defp route("GET", "/api/v1/schedule", conn, _body) do
    if invalid_uuid?(conn.query_params["semester_id"]),
      do: validation(conn, ["semester_id"]),
      else: data(conn, 200, %{"days" => []})
  end

  defp route("POST", "/api/v1/semesters", conn, body) do
    cond do
      body["label"] == "" or body["start_date"] == "not-a-date" ->
        validation(conn, ["label", "start_date", "end_date"])

      repeated_request?(conn, body) ->
        error(conn, 409)

      true ->
        data(conn, 201, Map.merge(semester(), body))
    end
  end

  defp route("GET", "/api/v1/semesters", conn, _body) do
    if invalid_query?(conn, ["page", "page_size", "active", "sort"]),
      do: validation(conn, ["page", "page_size", "active", "sort"]),
      else: list(conn, [semester()])
  end

  defp route("GET", "/api/v1/semesters/" <> id, conn, _body),
    do: uuid_data_or_404(conn, id, semester(id))

  defp route("PATCH", "/api/v1/semesters/" <> _id, conn, body),
    do:
      if(too_long?(body["label"], 20) or body["start_date"] == "nope",
        do: validation(conn, ["label", "start_date", "end_date"]),
        else: data(conn, 200, Map.merge(semester(), body))
      )

  defp route("DELETE", "/api/v1/semesters/" <> _id, conn, _body), do: empty(conn, 204)

  defp route("POST", "/api/v1/enrollments", conn, body) do
    cond do
      body["semester_id"] == @missing_uuid or body["enrollment_id"] == @missing_uuid ->
        error(conn, 404)

      repeated_request?(conn, body) ->
        error(conn, 409)

      invalid_enrollment?(body) ->
        validation(conn, [
          "semester_id",
          "discipline_id",
          "title",
          "professor",
          "credits",
          "color",
          "absence_limit"
        ])

      not Map.has_key?(body, "semester_id") ->
        validation(conn, ["semester_id", "title", "discipline_id"])

      true ->
        data(conn, 201, Map.merge(enrollment(), body))
    end
  end

  defp route("GET", "/api/v1/enrollments", conn, _body) do
    if invalid_query?(conn, ["page", "page_size", "semester_id", "source"]),
      do: validation(conn, ["page", "page_size", "semester_id", "source"]),
      else: list(conn, [enrollment()])
  end

  defp route(method, "/api/v1/enrollments/" <> rest, conn, body) do
    case String.split(rest, "/") do
      [id] when method == "GET" ->
        uuid_data_or_404(conn, id, enrollment(id))

      [id] when method == "PATCH" ->
        if invalid_enrollment_update?(body),
          do: validation(conn, ["title", "professor", "credits", "color", "absence_limit"]),
          else: uuid_data_or_404(conn, id, Map.merge(enrollment(id), body))

      [_id] when method == "DELETE" ->
        empty(conn, 204)

      [id, "meetings"] ->
        nested_collection_or_post(method, conn, id, body, meeting(), [
          "day_of_week",
          "starts_at",
          "ends_at",
          "location"
        ])

      [id, "grades"] ->
        nested_collection_or_post(method, conn, id, body, grade(), [
          "label",
          "score",
          "max_score",
          "weight"
        ])

      [id, "grades", "summary"] ->
        if valid_uuid?(id), do: data(conn, 200, grade_summary()), else: error(conn, 404)

      [id, "absences"] ->
        nested_collection_or_post(method, conn, id, body, absence(), ["date", "count", "note"])

      [id, "absences", "summary"] ->
        if valid_uuid?(id),
          do: data(conn, 200, %{"used" => 2, "remaining" => 18, "status" => "ok"}),
          else: error(conn, 404)

      _ ->
        error(conn, 404)
    end
  end

  defp route("PATCH", "/api/v1/meetings/" <> _id, conn, body) do
    if invalid_meeting?(body) do
      validation(conn, ["day_of_week", "starts_at", "ends_at"])
    else
      data(conn, 200, Map.merge(meeting(), body))
    end
  end

  defp route("DELETE", "/api/v1/meetings/" <> _id, conn, _body), do: empty(conn, 204)

  defp route("PATCH", "/api/v1/grades/" <> _id, conn, body) do
    if invalid_grade?(body) do
      validation(conn, ["label", "score", "max_score", "weight"])
    else
      data(conn, 200, Map.merge(grade(), body))
    end
  end

  defp route("DELETE", "/api/v1/grades/" <> _id, conn, _body), do: empty(conn, 204)
  defp route("DELETE", "/api/v1/absences/" <> _id, conn, _body), do: empty(conn, 204)

  defp route("POST", "/api/v1/tasks", conn, body) do
    cond do
      body["enrollment_id"] == @missing_uuid ->
        error(conn, 404)

      invalid_task?(body) ->
        validation(conn, [
          "title",
          "enrollment_id",
          "kind",
          "notes",
          "due_at",
          "priority",
          "status"
        ])

      true ->
        data(conn, 201, Map.merge(task(), body))
    end
  end

  defp route("GET", "/api/v1/tasks", conn, _body) do
    if invalid_query?(conn, [
         "page",
         "page_size",
         "semester_id",
         "enrollment_id",
         "status",
         "kind",
         "due_before",
         "due_after",
         "sort"
       ]),
       do:
         validation(conn, [
           "page",
           "page_size",
           "semester_id",
           "enrollment_id",
           "status",
           "kind",
           "due_before",
           "due_after",
           "sort"
         ]),
       else: list(conn, [task()])
  end

  defp route(method, "/api/v1/tasks/" <> rest, conn, body) do
    case String.split(rest, "/") do
      [id] when method == "GET" ->
        uuid_data_or_404(conn, id, task(id))

      [id] when method == "PATCH" ->
        if invalid_task_update?(body),
          do: validation(conn, ["title", "kind", "priority", "status"]),
          else: uuid_data_or_404(conn, id, Map.merge(task(id), body))

      [_id] when method == "DELETE" ->
        empty(conn, 204)

      [id, "status"] when method == "PATCH" ->
        if body["status"] == "late",
          do: validation(conn, ["status"]),
          else: uuid_data_or_404(conn, id, Map.merge(task(id), body))

      _ ->
        error(conn, 404)
    end
  end

  defp route(_method, _path, conn, _body), do: error(conn, 404)

  defp nested_collection_or_post("GET", conn, id, _body, item, _fields),
    do: if(valid_uuid?(id), do: collection(conn, [item]), else: error(conn, 404))

  defp nested_collection_or_post("POST", conn, id, body, item, fields) do
    cond do
      id == @missing_uuid -> error(conn, 404)
      Enum.any?(fields, &invalid_field?(body, &1)) -> validation(conn, fields)
      repeated_request?(conn, body) -> error(conn, 409)
      true -> data(conn, 201, Map.merge(item, body))
    end
  end

  defp uuid_data_or_404(conn, id, value),
    do: if(valid_uuid?(id), do: data(conn, 200, value), else: error(conn, 404))

  defp authorized(conn, fun) do
    if get_req_header(conn, "authorization") == ["Bearer test-token"],
      do: fun.(),
      else: error(conn, 401)
  end

  defp repeated_request?(conn, body) do
    key = {conn.method, conn.request_path, body}
    seen? = Process.get(key, false)
    Process.put(key, true)
    seen?
  end

  defp invalid_query?(conn, fields) do
    params = conn.query_params

    Enum.any?(fields, fn
      "page" ->
        params["page"] == "0"

      "page_size" ->
        params["page_size"] == "101"

      field when field in ["semester_id", "enrollment_id", "unit_id"] ->
        invalid_uuid?(params[field])

      "q" ->
        too_long?(params["q"], 80)

      "active" ->
        params["active"] == "maybe"

      "sort" ->
        params["sort"] == "created_at"

      field ->
        params[field] in ["imported", "not-a-status", "late", "quiz", "nope"]
    end)
  end

  defp invalid_sources?(sources),
    do:
      is_list(sources) and
        (Enum.uniq(sources) != sources or Enum.any?(sources, &(&1 not in ["schedule", "grades"])))

  defp invalid_enrollment?(body),
    do:
      invalid_uuid?(body["semester_id"]) or invalid_uuid?(body["discipline_id"]) or
        body["title"] == "" or too_long?(body["professor"], 120) or
        invalid_number?(body["credits"], 0, 40) or invalid_color?(body["color"]) or
        invalid_number?(body["absence_limit"], 0, 200)

  defp invalid_enrollment_update?(body),
    do:
      body["title"] == "" or too_long?(body["professor"], 120) or
        invalid_number?(body["credits"], 0, 40) or invalid_color?(body["color"]) or
        invalid_number?(body["absence_limit"], 0, 200)

  defp invalid_task?(body),
    do:
      body["title"] in ["", nil] or invalid_uuid?(body["enrollment_id"]) or
        body["kind"] not in ["assignment", nil] or too_long?(body["notes"], 5000) or
        body["due_at"] == "tomorrow" or body["priority"] not in ["normal", nil] or
        body["status"] not in ["todo", nil]

  defp invalid_task_update?(body),
    do:
      too_long?(body["title"], 160) or body["kind"] == "quiz" or body["priority"] == "urgent" or
        body["status"] == "late"

  defp invalid_meeting?(body),
    do:
      invalid_number?(body["day_of_week"], 1, 7) or body["starts_at"] in ["25:00", "8am"] or
        body["ends_at"] in ["07:99", "07:00"] or too_long?(body["location"], 120)

  defp invalid_grade?(body),
    do:
      body["label"] == "" or too_long?(body["label"], 80) or
        invalid_number?(body["score"], 0, 10_000) or
        invalid_number?(body["max_score"], 0.0001, 10_000) or
        invalid_number?(body["weight"], 0.0001, 10_000)

  defp invalid_field?(body, field),
    do:
      invalid_meeting?(body) or invalid_grade?(body) or invalid_absence?(body) or
        Map.get(body, field) in ["", nil]

  defp invalid_absence?(body),
    do:
      body["date"] == "not-a-date" or invalid_number?(body["count"], 1, 10) or
        too_long?(body["note"], 200)

  defp invalid_uuid?(nil), do: false
  defp invalid_uuid?(value), do: not valid_uuid?(value)

  defp valid_uuid?(value),
    do:
      is_binary(value) and
        value =~ ~r/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/

  defp too_long?(nil, _max), do: false
  defp too_long?(value, max), do: is_binary(value) and String.length(value) > max
  defp invalid_color?(nil), do: false
  defp invalid_color?(value), do: not (is_binary(value) and value =~ ~r/^#[0-9A-Fa-f]{6}$/)
  defp invalid_number?(nil, _min, _max), do: false
  defp invalid_number?(value, min, max), do: not is_number(value) or value < min or value > max

  defp read_json_body(conn) do
    case read_body(conn) do
      {:ok, "", _conn} -> %{}
      {:ok, body, _conn} -> Jason.decode!(body)
      _ -> %{}
    end
  end

  defp json(conn, status, body),
    do:
      conn |> put_resp_content_type("application/json") |> send_resp(status, Jason.encode!(body))

  defp data(conn, status, body), do: json(conn, status, %{"data" => body})

  defp list(conn, items),
    do:
      json(conn, 200, %{
        "data" => items,
        "meta" => %{"page" => 1, "page_size" => 25, "total" => length(items)}
      })

  defp collection(conn, items), do: json(conn, 200, %{"data" => items})

  defp validation(conn, fields),
    do:
      json(conn, 422, %{
        "errors" => %{
          "detail" => "Validation failed",
          "fields" => Map.new(fields, &{&1, ["is invalid"]})
        }
      })

  defp error(conn, status), do: json(conn, status, %{"errors" => %{"detail" => "Request failed"}})
  defp empty(conn, status), do: send_resp(conn, status, "")

  defp user, do: %{"id" => @uuid, "usp_username" => "1234567", "name" => "Test Student"}
  defp university(id \\ @uuid), do: %{"id" => id, "name" => "Universidade de Sao Paulo"}
  defp discipline(id \\ @uuid), do: %{"id" => id, "name" => "Calculo I"}
  defp semester(id \\ @uuid), do: %{"id" => id, "label" => "2026.2", "active" => true}

  defp enrollment(id \\ @uuid),
    do: %{
      "id" => id,
      "title" => "MAC0110 Introducao a Computacao",
      "source" => "manual",
      "professor" => "Profa. Ana",
      "meetings" => []
    }

  defp meeting,
    do: %{
      "id" => @uuid,
      "day_of_week" => 2,
      "starts_at" => "08:00",
      "ends_at" => "10:00",
      "location" => "IME B-12"
    }

  defp grade,
    do: %{"id" => @uuid, "label" => "P1", "score" => 8.5, "max_score" => 10.0, "weight" => 1.0}

  defp grade_summary,
    do: %{
      "weighted_average" => 8.5,
      "graded_weight" => 1.0,
      "remaining_weight" => 0.0,
      "passing_average" => 5.0,
      "status" => "on_track"
    }

  defp absence, do: %{"id" => @uuid, "date" => "2026-09-12", "count" => 2, "note" => "medical"}

  defp task(id \\ @uuid),
    do: %{
      "id" => id,
      "title" => "Lista 1",
      "kind" => "assignment",
      "status" => "todo",
      "priority" => "normal"
    }
end

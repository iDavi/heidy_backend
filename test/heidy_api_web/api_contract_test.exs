defmodule HeidyApiWeb.ApiContractTest do
  use HeidyApi.ApiContractCase, async: true

  @base "/api/v1"

  describe "public system and auth routes" do
    test "GET /health returns status and version" do
      conn = get(api_conn(), @base <> "/health")

      body = json_response(conn, 200)
      assert %{"status" => "ok", "version" => version} = body
      assert is_binary(version)
    end

    test "GET /auth/login-key returns an HPKE public key" do
      conn = get(api_conn(), @base <> "/auth/login-key")

      key = conn |> json_response(200) |> assert_data_envelope()
      assert %{"key_id" => key_id, "alg" => alg, "public_key" => public_key} = key
      assert is_binary(key_id)
      assert alg =~ "HPKE"
      assert is_binary(public_key)
    end

    test "POST /auth/login verifies USP credentials and returns session artifacts" do
      conn = post(api_conn(), @base <> "/auth/login", Jason.encode!(login_input()))

      result = conn |> json_response(200) |> assert_data_envelope()
      assert %{"user" => user, "token" => token, "credential_blob" => blob} = result
      assert %{"usp_username" => "1234567"} = user
      assert is_binary(token)
      assert %{"blob" => blob_text, "expires_at" => expires_at} = blob
      assert is_binary(blob_text)
      assert is_binary(expires_at)
    end

    test "POST /auth/login reports field validation errors" do
      conn = post(api_conn(), @base <> "/auth/login", Jason.encode!(%{"usp_username" => "abc"}))

      conn
      |> json_response(422)
      |> assert_validation_error("envelope")
    end

    test "DELETE /auth/logout revokes the current token" do
      conn = delete(auth_conn(), @base <> "/auth/logout")

      assert json_response(conn, 204) == nil
    end
  end

  describe "current user routes" do
    test "GET /me returns the current user profile" do
      conn = get(auth_conn(), @base <> "/me")

      user = conn |> json_response(200) |> assert_data_envelope()
      assert %{"id" => id, "usp_username" => "1234567", "name" => name} = user
      assert is_binary(id)
      assert is_binary(name)
    end

    test "PATCH /me updates profile fields" do
      conn = patch(auth_conn(), @base <> "/me", Jason.encode!(%{"name" => "Ana"}))

      user = conn |> json_response(200) |> assert_data_envelope()
      assert %{"name" => "Ana"} = user
    end

    test "DELETE /me/credential revokes all credential blobs" do
      conn = delete(auth_conn(), @base <> "/me/credential")

      assert json_response(conn, 204) == nil
    end

    test "DELETE /me deletes the account" do
      conn = delete(auth_conn(), @base <> "/me")

      assert json_response(conn, 204) == nil
    end
  end

  describe "USP sync routes" do
    test "POST /usp/sync accepts a credential blob and starts async work" do
      conn = post(auth_conn(), @base <> "/usp/sync", Jason.encode!(sync_input()))

      sync = conn |> json_response(202) |> assert_data_envelope()
      assert %{"id" => id, "status" => "pending", "sources" => ["schedule", "grades"]} = sync
      assert is_binary(id)
    end

    test "GET /usp/sync lists recent sync runs" do
      conn = get(auth_conn(), @base <> "/usp/sync")

      conn
      |> json_response(200)
      |> assert_list_envelope()
    end

    test "GET /usp/sync/:id polls a sync run" do
      conn = get(auth_conn(), @base <> "/usp/sync/#{uuid()}")

      sync = conn |> json_response(200) |> assert_data_envelope()
      assert %{"id" => id, "status" => status} = sync
      assert status in ["pending", "running", "succeeded", "failed"]
      assert is_binary(id)
    end
  end

  describe "semester and enrollment routes" do
    test "POST /semesters creates a semester" do
      conn = post(auth_conn(), @base <> "/semesters", Jason.encode!(semester_input()))

      semester = conn |> json_response(201) |> assert_data_envelope()
      assert %{"name" => "2026.2", "active" => true} = semester
    end

    test "GET /semesters lists semesters" do
      conn = get(auth_conn(), @base <> "/semesters?page=1&page_size=25")

      conn
      |> json_response(200)
      |> assert_list_envelope()
    end

    test "GET /semesters/:id returns a semester" do
      conn = get(auth_conn(), @base <> "/semesters/#{uuid()}")

      semester = conn |> json_response(200) |> assert_data_envelope()
      assert %{"id" => id, "name" => name} = semester
      assert is_binary(id)
      assert is_binary(name)
    end

    test "PATCH /semesters/:id updates a semester" do
      conn =
        patch(auth_conn(), @base <> "/semesters/#{uuid()}", Jason.encode!(%{"active" => false}))

      semester = conn |> json_response(200) |> assert_data_envelope()
      assert %{"active" => false} = semester
    end

    test "DELETE /semesters/:id deletes a semester" do
      conn = delete(auth_conn(), @base <> "/semesters/#{uuid()}")

      assert json_response(conn, 204) == nil
    end

    test "POST /enrollments adds a class" do
      conn = post(auth_conn(), @base <> "/enrollments", Jason.encode!(enrollment_input()))

      enrollment = conn |> json_response(201) |> assert_data_envelope()
      assert %{"name" => name, "source" => "manual"} = enrollment
      assert name =~ "MAC0110"
    end

    test "GET /enrollments lists classes" do
      conn = get(auth_conn(), @base <> "/enrollments?semester_id=#{uuid()}")

      conn
      |> json_response(200)
      |> assert_list_envelope()
    end

    test "GET /enrollments/:id returns class details with meetings" do
      conn = get(auth_conn(), @base <> "/enrollments/#{uuid()}")

      enrollment = conn |> json_response(200) |> assert_data_envelope()
      assert %{"id" => id, "meetings" => meetings} = enrollment
      assert is_binary(id)
      assert is_list(meetings)
    end

    test "PATCH /enrollments/:id updates a class" do
      conn =
        patch(
          auth_conn(),
          @base <> "/enrollments/#{uuid()}",
          Jason.encode!(%{"professor" => "Prof. Beto"})
        )

      enrollment = conn |> json_response(200) |> assert_data_envelope()
      assert %{"professor" => "Prof. Beto"} = enrollment
    end

    test "DELETE /enrollments/:id removes a class" do
      conn = delete(auth_conn(), @base <> "/enrollments/#{uuid()}")

      assert json_response(conn, 204) == nil
    end
  end

  describe "meeting and schedule routes" do
    test "POST /enrollments/:id/meetings adds a time slot" do
      conn =
        post(
          auth_conn(),
          @base <> "/enrollments/#{uuid()}/meetings",
          Jason.encode!(meeting_input())
        )

      meeting = conn |> json_response(201) |> assert_data_envelope()
      assert %{"day_of_week" => 2, "starts_at" => "08:00", "ends_at" => "10:00"} = meeting
    end

    test "GET /enrollments/:id/meetings lists class time slots" do
      conn = get(auth_conn(), @base <> "/enrollments/#{uuid()}/meetings")

      conn
      |> json_response(200)
      |> assert_list_envelope()
    end

    test "PATCH /meetings/:id updates a time slot" do
      conn =
        patch(
          auth_conn(),
          @base <> "/meetings/#{uuid()}",
          Jason.encode!(%{"location" => "IME B-10"})
        )

      meeting = conn |> json_response(200) |> assert_data_envelope()
      assert %{"location" => "IME B-10"} = meeting
    end

    test "DELETE /meetings/:id removes a time slot" do
      conn = delete(auth_conn(), @base <> "/meetings/#{uuid()}")

      assert json_response(conn, 204) == nil
    end

    test "GET /schedule returns a computed weekly schedule" do
      conn = get(auth_conn(), @base <> "/schedule?semester_id=#{uuid()}")

      schedule = conn |> json_response(200) |> assert_data_envelope()
      assert %{"days" => days} = schedule
      assert is_list(days)
    end
  end

  describe "task routes" do
    test "POST /tasks creates a task" do
      conn = post(auth_conn(), @base <> "/tasks", Jason.encode!(task_input()))

      task = conn |> json_response(201) |> assert_data_envelope()
      assert %{"title" => "Lista 1", "status" => "todo", "priority" => "normal"} = task
    end

    test "GET /tasks lists tasks" do
      conn = get(auth_conn(), @base <> "/tasks?status=todo&semester_id=#{uuid()}")

      conn
      |> json_response(200)
      |> assert_list_envelope()
    end

    test "GET /tasks/:id returns a task" do
      conn = get(auth_conn(), @base <> "/tasks/#{uuid()}")

      task = conn |> json_response(200) |> assert_data_envelope()
      assert %{"id" => id, "title" => title} = task
      assert is_binary(id)
      assert is_binary(title)
    end

    test "PATCH /tasks/:id updates a task" do
      conn =
        patch(auth_conn(), @base <> "/tasks/#{uuid()}", Jason.encode!(%{"status" => "doing"}))

      task = conn |> json_response(200) |> assert_data_envelope()
      assert %{"status" => "doing"} = task
    end

    test "PATCH /tasks/:id/status transitions status" do
      conn =
        patch(
          auth_conn(),
          @base <> "/tasks/#{uuid()}/status",
          Jason.encode!(%{"status" => "done"})
        )

      task = conn |> json_response(200) |> assert_data_envelope()
      assert %{"status" => "done"} = task
    end

    test "DELETE /tasks/:id deletes a task" do
      conn = delete(auth_conn(), @base <> "/tasks/#{uuid()}")

      assert json_response(conn, 204) == nil
    end
  end

  describe "grade and absence routes" do
    test "POST /enrollments/:id/grades adds a grade" do
      conn =
        post(auth_conn(), @base <> "/enrollments/#{uuid()}/grades", Jason.encode!(grade_input()))

      grade = conn |> json_response(201) |> assert_data_envelope()
      assert %{"title" => "P1", "score" => 8.5, "max_score" => 10.0} = grade
    end

    test "GET /enrollments/:id/grades lists grades" do
      conn = get(auth_conn(), @base <> "/enrollments/#{uuid()}/grades")

      conn
      |> json_response(200)
      |> assert_list_envelope()
    end

    test "GET /enrollments/:id/grades/summary returns computed grade summary" do
      conn = get(auth_conn(), @base <> "/enrollments/#{uuid()}/grades/summary")

      summary = conn |> json_response(200) |> assert_data_envelope()
      assert %{"current_score" => current_score, "max_score" => max_score} = summary
      assert is_number(current_score)
      assert is_number(max_score)
    end

    test "PATCH /grades/:id updates a grade" do
      conn = patch(auth_conn(), @base <> "/grades/#{uuid()}", Jason.encode!(%{"score" => 9.0}))

      grade = conn |> json_response(200) |> assert_data_envelope()
      assert %{"score" => 9.0} = grade
    end

    test "DELETE /grades/:id deletes a grade" do
      conn = delete(auth_conn(), @base <> "/grades/#{uuid()}")

      assert json_response(conn, 204) == nil
    end

    test "POST /enrollments/:id/absences logs an absence" do
      conn =
        post(
          auth_conn(),
          @base <> "/enrollments/#{uuid()}/absences",
          Jason.encode!(absence_input())
        )

      absence = conn |> json_response(201) |> assert_data_envelope()
      assert %{"date" => "2026-09-12", "count" => 2} = absence
    end

    test "GET /enrollments/:id/absences lists absences" do
      conn = get(auth_conn(), @base <> "/enrollments/#{uuid()}/absences")

      conn
      |> json_response(200)
      |> assert_list_envelope()
    end

    test "GET /enrollments/:id/absences/summary returns computed attendance summary" do
      conn = get(auth_conn(), @base <> "/enrollments/#{uuid()}/absences/summary")

      summary = conn |> json_response(200) |> assert_data_envelope()
      assert %{"absence_count" => absence_count, "absence_limit" => absence_limit} = summary
      assert is_integer(absence_count)
      assert is_integer(absence_limit)
    end

    test "DELETE /absences/:id removes an absence" do
      conn = delete(auth_conn(), @base <> "/absences/#{uuid()}")

      assert json_response(conn, 204) == nil
    end
  end

  describe "catalog routes" do
    test "GET /universities lists/searches universities" do
      conn = get(auth_conn(), @base <> "/universities?q=usp")

      conn
      |> json_response(200)
      |> assert_list_envelope()
    end

    test "GET /universities/:id returns university detail" do
      conn = get(auth_conn(), @base <> "/universities/#{uuid()}")

      university = conn |> json_response(200) |> assert_data_envelope()
      assert %{"id" => id, "name" => name} = university
      assert is_binary(id)
      assert is_binary(name)
    end

    test "GET /universities/:id/units lists units" do
      conn = get(auth_conn(), @base <> "/universities/#{uuid()}/units")

      conn
      |> json_response(200)
      |> assert_list_envelope()
    end

    test "GET /units/:id/courses lists courses" do
      conn = get(auth_conn(), @base <> "/units/#{uuid()}/courses")

      conn
      |> json_response(200)
      |> assert_list_envelope()
    end

    test "GET /disciplines searches disciplines" do
      conn = get(auth_conn(), @base <> "/disciplines?q=calculo")

      conn
      |> json_response(200)
      |> assert_list_envelope()
    end

    test "GET /disciplines/:id returns discipline detail" do
      conn = get(auth_conn(), @base <> "/disciplines/#{uuid()}")

      discipline = conn |> json_response(200) |> assert_data_envelope()
      assert %{"id" => id, "name" => name} = discipline
      assert is_binary(id)
      assert is_binary(name)
    end
  end
end

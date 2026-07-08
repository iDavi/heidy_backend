defmodule HeidyApiWeb.TasksContractTest do
  @moduledoc "Contract for the task (`/tasks`) routes."
  use HeidyApi.ApiContractCase, async: true

  describe "tasks" do
    test "a student can create a task that starts in the todo state" do
      # Arrange
      attributes = task_input()
      expected = %{"title" => "Lista 1", "status" => "todo", "priority" => "normal"}

      # Act
      response = post(auth_conn(), api_path("/tasks"), Jason.encode!(attributes))

      # Assert
      task = response |> json_response(201) |> assert_data_envelope()
      assert expected == Map.take(task, ["title", "status", "priority"])
    end

    test "creating a task validates title, enrollment id, enum fields, notes, and due date" do
      # Arrange
      attributes = %{
        "title" => "",
        "enrollment_id" => invalid_uuid(),
        "kind" => "quiz",
        "notes" => too_long(5000),
        "due_at" => "tomorrow",
        "priority" => "urgent",
        "status" => "blocked"
      }

      # Act
      response = post(auth_conn(), api_path("/tasks"), Jason.encode!(attributes))

      # Assert
      body = json_response(response, 422)
      assert_validation_error(body, "title")
      assert_validation_error(body, "enrollment_id")
      assert_validation_error(body, "kind")
      assert_validation_error(body, "notes")
      assert_validation_error(body, "due_at")
      assert_validation_error(body, "priority")
      assert_validation_error(body, "status")
    end

    test "creating a task for an unknown class returns not found" do
      # Arrange
      attributes =
        task_input() |> Map.put("enrollment_id", "00000000-0000-4000-8000-000000000000")

      # Act
      response = post(auth_conn(), api_path("/tasks"), Jason.encode!(attributes))

      # Assert
      response
      |> json_response(404)
      |> assert_error_detail()
    end

    test "a student can list tasks filtered by status and semester" do
      # Arrange
      semester_id = uuid()

      # Act
      response = get(auth_conn(), api_path("/tasks?status=todo&semester_id=#{semester_id}"))

      # Assert
      response
      |> json_response(200)
      |> assert_list_envelope()
    end

    test "listing tasks validates pagination, filters, and sort" do
      # Arrange
      invalid_query =
        "/tasks?page=0&page_size=101&semester_id=#{invalid_uuid()}&enrollment_id=#{invalid_uuid()}&status=late&kind=quiz&due_before=nope&due_after=nope&sort=created_at"

      # Act
      response = get(auth_conn(), api_path(invalid_query))

      # Assert
      body = json_response(response, 422)
      assert_validation_error(body, "page")
      assert_validation_error(body, "page_size")
      assert_validation_error(body, "semester_id")
      assert_validation_error(body, "enrollment_id")
      assert_validation_error(body, "status")
      assert_validation_error(body, "kind")
      assert_validation_error(body, "due_before")
      assert_validation_error(body, "due_after")
      assert_validation_error(body, "sort")
    end

    test "a student can read a single task" do
      # Arrange
      task_id = uuid()

      # Act
      response = get(auth_conn(), api_path("/tasks/#{task_id}"))

      # Assert
      task = response |> json_response(200) |> assert_data_envelope()
      assert %{"id" => id, "title" => title} = task
      assert is_binary(id)
      assert is_binary(title)
    end

    test "reading a task with a malformed id returns not found" do
      # Arrange
      task_id = invalid_uuid()

      # Act
      response = get(auth_conn(), api_path("/tasks/#{task_id}"))

      # Assert
      response
      |> json_response(404)
      |> assert_error_detail()
    end

    test "a student can update a task's fields" do
      # Arrange
      task_id = uuid()
      changes = %{"status" => "doing"}
      expected_status = "doing"

      # Act
      response = patch(auth_conn(), api_path("/tasks/#{task_id}"), Jason.encode!(changes))

      # Assert
      task = response |> json_response(200) |> assert_data_envelope()
      assert %{"status" => ^expected_status} = task
    end

    test "updating a task validates non-empty changes and field constraints" do
      # Arrange
      task_id = uuid()

      changes = %{
        "title" => too_long(160),
        "kind" => "quiz",
        "priority" => "urgent",
        "status" => "late"
      }

      # Act
      response = patch(auth_conn(), api_path("/tasks/#{task_id}"), Jason.encode!(changes))

      # Assert
      body = json_response(response, 422)
      assert_validation_error(body, "title")
      assert_validation_error(body, "kind")
      assert_validation_error(body, "priority")
      assert_validation_error(body, "status")
    end

    test "a student can transition a task's status through the dedicated route" do
      # Arrange
      task_id = uuid()
      changes = %{"status" => "done"}
      expected_status = "done"

      # Act
      response = patch(auth_conn(), api_path("/tasks/#{task_id}/status"), Jason.encode!(changes))

      # Assert
      task = response |> json_response(200) |> assert_data_envelope()
      assert %{"status" => ^expected_status} = task
    end

    test "transitioning a task rejects unknown statuses" do
      # Arrange
      task_id = uuid()
      changes = %{"status" => "late"}

      # Act
      response = patch(auth_conn(), api_path("/tasks/#{task_id}/status"), Jason.encode!(changes))

      # Assert
      response
      |> json_response(422)
      |> assert_validation_error("status")
    end

    test "a student can delete a task" do
      # Arrange
      task_id = uuid()
      expected_status = 204

      # Act
      response = delete(auth_conn(), api_path("/tasks/#{task_id}"))

      # Assert
      assert json_response(response, expected_status) == nil
    end
  end
end

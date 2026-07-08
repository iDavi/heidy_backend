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

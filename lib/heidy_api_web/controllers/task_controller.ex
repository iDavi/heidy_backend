defmodule HeidyApiWeb.TaskController do
  use HeidyApiWeb, :controller

  alias HeidyApi.Planner
  alias HeidyApi.Planner.Task

  @create_schema [
    title: [type: :string, required: true, max: 160],
    enrollment_id: [type: :uuid],
    notes: [type: :string, max: 5000],
    kind: [type: :enum, values: Task.kinds()],
    status: [type: :enum, values: Task.statuses()],
    priority: [type: :enum, values: Task.priorities()],
    due_at: [type: :datetime]
  ]

  @update_schema Keyword.replace!(@create_schema, :title, type: :string, max: 160)

  @index_schema [
    semester_id: [type: :uuid],
    enrollment_id: [type: :uuid],
    status: [type: :enum, values: Task.statuses()],
    kind: [type: :enum, values: Task.kinds()],
    due_before: [type: :datetime],
    due_after: [type: :datetime],
    sort: [type: :enum, values: ~w(due_at -due_at priority -priority title -title)]
  ]

  def create(conn, params) do
    with {:ok, attrs} <- Params.validate(params, @create_schema),
         {:ok, task} <- Planner.create_task(current_user(conn), attrs) do
      data(conn, task, :created)
    end
  end

  def index(conn, params) do
    with {:ok, filters} <- Params.validate(params, Params.pagination() ++ @index_schema) do
      page(conn, Planner.list_tasks(current_user(conn), filters))
    end
  end

  def show(conn, %{"id" => id}) do
    with {:ok, task} <- Planner.fetch_task(current_user(conn), id) do
      data(conn, task)
    end
  end

  def update(conn, %{"id" => id} = params) do
    with {:ok, task} <- Planner.fetch_task(current_user(conn), id),
         {:ok, attrs} <- Params.validate(params, @update_schema),
         {:ok, task} <- Planner.update_task(task, attrs) do
      data(conn, task)
    end
  end

  def update_status(conn, %{"id" => id} = params) do
    with {:ok, task} <- Planner.fetch_task(current_user(conn), id),
         {:ok, attrs} <-
           Params.validate(params, status: [type: :enum, required: true, values: Task.statuses()]),
         {:ok, task} <- Planner.update_task(task, attrs) do
      data(conn, task)
    end
  end

  def delete(conn, %{"id" => id}) do
    :ok = Planner.delete_task(current_user(conn), id)
    no_content(conn)
  end
end

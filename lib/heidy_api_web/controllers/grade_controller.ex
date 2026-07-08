defmodule HeidyApiWeb.GradeController do
  use HeidyApiWeb, :controller

  alias HeidyApi.Planner

  @create_schema [
    label: [type: :string, required: true, max: 80],
    score: [type: :number, min: 0],
    max_score: [type: :number, required: true, gt: 0],
    weight: [type: :number, required: true, gt: 0]
  ]

  @update_schema [
    label: [type: :string, max: 80],
    score: [type: :number, min: 0],
    max_score: [type: :number, gt: 0],
    weight: [type: :number, gt: 0]
  ]

  def create(conn, %{"enrollment_id" => enrollment_id} = params) do
    with {:ok, enrollment} <- Planner.fetch_enrollment(current_user(conn), enrollment_id),
         {:ok, attrs} <- Params.validate(params, @create_schema),
         {:ok, grade} <- Planner.create_grade(enrollment, attrs) do
      data(conn, grade, :created)
    end
  end

  def index(conn, %{"enrollment_id" => enrollment_id}) do
    with {:ok, enrollment} <- Planner.fetch_enrollment(current_user(conn), enrollment_id) do
      collection(conn, Planner.list_grades(enrollment))
    end
  end

  def summary(conn, %{"enrollment_id" => enrollment_id}) do
    with {:ok, enrollment} <- Planner.fetch_enrollment(current_user(conn), enrollment_id) do
      data(conn, Planner.grade_summary(enrollment))
    end
  end

  def update(conn, %{"id" => id} = params) do
    with {:ok, grade} <- Planner.fetch_grade(current_user(conn), id),
         {:ok, attrs} <- Params.validate(params, @update_schema),
         {:ok, grade} <- Planner.update_grade(grade, attrs) do
      data(conn, grade)
    end
  end

  def delete(conn, %{"id" => id}) do
    :ok = Planner.delete_grade(current_user(conn), id)
    no_content(conn)
  end
end

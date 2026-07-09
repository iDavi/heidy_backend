defmodule HeidyApiWeb.AbsenceController do
  use HeidyApiWeb, :controller

  alias HeidyApi.Planner

  @create_schema [
    date: [type: :date, required: true],
    count: [type: :integer, min: 1, max: 10, default: 1],
    note: [type: :string, max: 200]
  ]

  def create(conn, %{"enrollment_id" => enrollment_id} = params) do
    with {:ok, enrollment} <- Planner.fetch_enrollment(current_user(conn), enrollment_id),
         {:ok, attrs} <- Params.validate(params, @create_schema),
         {:ok, absence} <- Planner.create_absence(enrollment, attrs) do
      data(conn, absence, :created)
    end
  end

  def index(conn, %{"enrollment_id" => enrollment_id}) do
    with {:ok, enrollment} <- Planner.fetch_enrollment(current_user(conn), enrollment_id) do
      collection(conn, Planner.list_absences(enrollment))
    end
  end

  def summary(conn, %{"enrollment_id" => enrollment_id}) do
    with {:ok, enrollment} <- Planner.fetch_enrollment(current_user(conn), enrollment_id) do
      data(conn, Planner.attendance_summary(enrollment))
    end
  end

  def delete(conn, %{"id" => id}) do
    :ok = Planner.delete_absence(current_user(conn), id)
    no_content(conn)
  end
end

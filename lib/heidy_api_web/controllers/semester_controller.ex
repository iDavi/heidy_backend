defmodule HeidyApiWeb.SemesterController do
  use HeidyApiWeb, :controller

  alias HeidyApi.Planner

  @create_schema [
    label: [type: :string, required: true, max: 20],
    start_date: [type: :date, required: true],
    end_date: [type: :date, required: true],
    active: [type: :boolean]
  ]

  @update_schema [
    label: [type: :string, max: 20],
    start_date: [type: :date],
    end_date: [type: :date],
    active: [type: :boolean]
  ]

  @index_schema [
    active: [type: :boolean],
    sort: [type: :enum, values: ~w(label -label start_date -start_date)]
  ]

  def create(conn, params) do
    with {:ok, attrs} <- Params.validate(params, @create_schema),
         {:ok, semester} <- Planner.create_semester(current_user(conn), attrs) do
      data(conn, semester, :created)
    end
  end

  def index(conn, params) do
    with {:ok, filters} <- Params.validate(params, Params.pagination() ++ @index_schema) do
      page(conn, Planner.list_semesters(current_user(conn), filters))
    end
  end

  def show(conn, %{"id" => id}) do
    with {:ok, semester} <- Planner.fetch_semester(current_user(conn), id) do
      data(conn, semester)
    end
  end

  def update(conn, %{"id" => id} = params) do
    with {:ok, semester} <- Planner.fetch_semester(current_user(conn), id),
         {:ok, attrs} <- Params.validate(params, @update_schema),
         {:ok, semester} <- Planner.update_semester(semester, attrs) do
      data(conn, semester)
    end
  end

  def delete(conn, %{"id" => id}) do
    :ok = Planner.delete_semester(current_user(conn), id)
    no_content(conn)
  end
end

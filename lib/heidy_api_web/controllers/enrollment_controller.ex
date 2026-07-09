defmodule HeidyApiWeb.EnrollmentController do
  use HeidyApiWeb, :controller

  alias HeidyApi.Planner

  @hex_color {~r/^#[0-9a-fA-F]{6}$/, "must be a hex color like #2F80ED"}

  @create_schema [
    semester_id: [type: :uuid, required: true],
    discipline_id: [type: :uuid],
    title: [type: :string, max: 160],
    professor: [type: :string, max: 120],
    credits: [type: :integer, min: 0, max: 40],
    color: [type: :string, format: @hex_color],
    absence_limit: [type: :integer, min: 0, max: 200]
  ]

  @update_schema [
    title: [type: :string, max: 160],
    professor: [type: :string, max: 120],
    credits: [type: :integer, min: 0, max: 40],
    color: [type: :string, format: @hex_color],
    absence_limit: [type: :integer, min: 0, max: 200],
    discipline_id: [type: :uuid]
  ]

  @index_schema [
    semester_id: [type: :uuid],
    source: [type: :enum, values: ~w(manual usp)]
  ]

  def create(conn, params) do
    with {:ok, attrs} <- validate_create(params),
         {:ok, enrollment} <- Planner.create_enrollment(current_user(conn), attrs) do
      data(conn, enrollment, :created)
    end
  end

  def index(conn, params) do
    with {:ok, filters} <- Params.validate(params, Params.pagination() ++ @index_schema) do
      page(conn, Planner.list_enrollments(current_user(conn), filters))
    end
  end

  def show(conn, %{"id" => id}) do
    with {:ok, enrollment} <- Planner.fetch_enrollment(current_user(conn), id) do
      data(conn, enrollment)
    end
  end

  def update(conn, %{"id" => id} = params) do
    with {:ok, enrollment} <- Planner.fetch_enrollment(current_user(conn), id),
         {:ok, attrs} <- Params.validate(params, @update_schema),
         {:ok, enrollment} <- Planner.update_enrollment(enrollment, attrs) do
      data(conn, enrollment)
    end
  end

  def delete(conn, %{"id" => id}) do
    :ok = Planner.delete_enrollment(current_user(conn), id)
    no_content(conn)
  end

  # A class needs a name: either a free-form title or a catalog discipline.
  defp validate_create(params) do
    missing_name? = blank?(params["title"]) and blank?(params["discipline_id"])

    extra =
      if missing_name? do
        message = "either title or discipline_id must be given"
        %{"title" => [message], "discipline_id" => [message]}
      else
        %{}
      end

    params |> Params.validate(@create_schema) |> Params.merge_errors(extra)
  end

  defp blank?(value), do: value in [nil, ""]
end

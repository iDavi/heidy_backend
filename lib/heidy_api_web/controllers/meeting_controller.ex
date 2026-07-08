defmodule HeidyApiWeb.MeetingController do
  use HeidyApiWeb, :controller

  alias HeidyApi.Planner

  @create_schema [
    day_of_week: [type: :integer, required: true, min: 1, max: 7],
    starts_at: [type: :time, required: true],
    ends_at: [type: :time, required: true],
    location: [type: :string, max: 120]
  ]

  @update_schema [
    day_of_week: [type: :integer, min: 1, max: 7],
    starts_at: [type: :time],
    ends_at: [type: :time],
    location: [type: :string, max: 120]
  ]

  def create(conn, %{"enrollment_id" => enrollment_id} = params) do
    with {:ok, enrollment} <- Planner.fetch_enrollment(current_user(conn), enrollment_id),
         {:ok, attrs} <- Params.validate(params, @create_schema),
         {:ok, meeting} <- Planner.create_meeting(enrollment, attrs) do
      data(conn, meeting, :created)
    end
  end

  def index(conn, %{"enrollment_id" => enrollment_id}) do
    with {:ok, enrollment} <- Planner.fetch_enrollment(current_user(conn), enrollment_id) do
      collection(conn, Planner.list_meetings(enrollment))
    end
  end

  def update(conn, %{"id" => id} = params) do
    with {:ok, meeting} <- Planner.fetch_meeting(current_user(conn), id),
         {:ok, attrs} <- validate_update(meeting, params),
         {:ok, meeting} <- Planner.update_meeting(meeting, attrs) do
      data(conn, meeting)
    end
  end

  defp validate_update(meeting, params) do
    params
    |> Params.validate(@update_schema)
    |> Params.merge_errors(time_order_errors(meeting, params))
  end

  # Cross-field: after the update the slot must still end after it starts.
  # Each side uses the incoming value when it parses, else the stored one.
  defp time_order_errors(meeting, params) do
    starts_at = effective_time(params["starts_at"], meeting.starts_at)
    ends_at = effective_time(params["ends_at"], meeting.ends_at)

    if Time.compare(ends_at, starts_at) != :gt do
      %{"ends_at" => ["must be after starts_at"]}
    else
      %{}
    end
  end

  defp effective_time(param, current) do
    case Params.validate(%{"value" => param}, value: [type: :time]) do
      {:ok, %{value: time}} -> time
      _absent_or_invalid -> current
    end
  end

  def delete(conn, %{"id" => id}) do
    :ok = Planner.delete_meeting(current_user(conn), id)
    no_content(conn)
  end
end

defmodule HeidyApiWeb.ScheduleController do
  use HeidyApiWeb, :controller

  alias HeidyApi.Planner

  def show(conn, params) do
    with {:ok, %{semester_id: semester_id}} <-
           Params.validate(params, semester_id: [type: :uuid, required: true]),
         {:ok, semester} <- Planner.fetch_semester(current_user(conn), semester_id) do
      data(conn, Planner.schedule(current_user(conn), semester))
    end
  end
end

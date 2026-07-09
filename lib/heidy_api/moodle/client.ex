defmodule HeidyApi.Moodle.Client do
  @moduledoc "Behaviour for clients that read a student's e-Disciplinas calendar."

  alias HeidyApi.Moodle.{ActivityDetail, Assignment, Course, CourseDetail, Session}

  @type error :: :invalid_credentials | :unavailable

  @callback login(username :: String.t(), password :: String.t()) ::
              {:ok, Session.t()} | {:error, error()}

  @callback fetch_assignments(Session.t()) :: {:ok, [Assignment.t()]} | {:error, error()}

  @callback fetch_courses(Session.t()) :: {:ok, [Course.t()]} | {:error, error()}

  @callback fetch_course(Session.t(), course_id :: pos_integer()) ::
              {:ok, CourseDetail.t()} | {:error, error()}

  @callback fetch_activity(Session.t(), activity_url :: String.t()) ::
              {:ok, ActivityDetail.t()} | {:error, error()}
end

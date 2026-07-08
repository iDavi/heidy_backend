defmodule HeidyApi.Usp.Client do
  @moduledoc """
  The behaviour every USP data source implementation satisfies.

  `HeidyApi.Usp.Client.Jupiter` is the real JupiterWeb implementation; the
  test suite configures a stub. Callers never see USP's wire shapes — only
  the normalized records in `HeidyApi.Usp.*`.
  """

  alias HeidyApi.Usp.{ClassSlot, EnrollmentRecord, Session, Student}

  @type error :: :invalid_credentials | :unavailable

  @doc "Performs a fresh USP login. The password must not outlive the call."
  @callback login(username :: String.t(), password :: String.t()) ::
              {:ok, Session.t()} | {:error, error()}

  @doc "Fetches the logged-in student's identity and program."
  @callback fetch_student(Session.t()) :: {:ok, Student.t()} | {:error, error()}

  @doc "Fetches the current weekly schedule grid."
  @callback fetch_schedule(Session.t()) :: {:ok, [ClassSlot.t()]} | {:error, error()}

  @doc "Lists the academic periods the student has records for (e.g. `20261`)."
  @callback list_periods(Session.t()) :: {:ok, [String.t()]} | {:error, error()}

  @doc "Fetches the student's enrollments for one period."
  @callback fetch_enrollments(Session.t(), period :: String.t()) ::
              {:ok, [EnrollmentRecord.t()]} | {:error, error()}
end

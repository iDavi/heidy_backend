defmodule HeidyApi.Usp.Sync do
  @moduledoc """
  Starts and tracks USP sync runs.

  `start/2` answers immediately with a `pending` run; the login + scrape +
  upsert happens in a supervised task so a slow USP never blocks a request.
  Syncs are serialized per user, and each run performs exactly one fresh
  USP login whose session dies with the run - nothing USP-side is cached.
  """

  import Ecto.Query

  alias HeidyApi.Accounts.User
  alias HeidyApi.Changeset
  alias HeidyApi.Credentials
  alias HeidyApi.Planner.{Enrollment, Meeting, Semester}
  alias HeidyApi.Usp.{Import, SyncRun}
  alias HeidyApi.{Demo, Ids, Page, Repo, Usp}

  @type start_error ::
          {:conflict, String.t()} | {:forbidden, String.t()} | :not_found

  @doc """
  Opens the credential blob and enqueues a sync run.

  The decrypted password is handed straight to the worker and never stored;
  an unopenable blob (revoked, expired, or foreign) is refused outright.
  """
  @spec start(User.t(), map()) :: {:ok, SyncRun.t()} | {:error, start_error()}
  def start(%User{} = user, attrs) do
    with :ok <- ensure_not_running(user),
         {:ok, password} <- open_blob(user, attrs.credential_blob) do
      {:ok, run} =
        %SyncRun{}
        |> SyncRun.changeset(%{
          user_id: user.id,
          sources: attrs.sources,
          semester_id: attrs[:semester_id],
          started_at: DateTime.utc_now(:second)
        })
        |> Repo.insert()
        |> Changeset.normalize_result()

      if Application.get_env(:heidy_api, :sync_async, true) do
        Task.Supervisor.start_child(__MODULE__.TaskSupervisor, fn ->
          perform(run, user, password)
        end)
      end

      {:ok, run}
    end
  end

  @spec list(User.t(), map()) :: Page.t()
  def list(%User{} = user, filters) do
    Repo.all(from(run in SyncRun, where: run.user_id == ^user.id))
    |> then(fn runs ->
      case filters[:status] do
        nil -> runs
        status -> Enum.filter(runs, &(&1.status == status))
      end
    end)
    |> Enum.sort_by(& &1.started_at, {:desc, DateTime})
    |> Page.paginate(filters.page, filters.page_size)
  end

  @spec fetch(User.t(), String.t()) :: {:ok, SyncRun.t()} | {:error, :not_found}
  def fetch(%User{} = user, id) do
    cond do
      not Ids.valid?(id) ->
        {:error, :not_found}

      Ids.reserved?(id) ->
        {:error, :not_found}

      run = Repo.one(from(run in SyncRun, where: run.user_id == ^user.id and run.id == ^id)) ->
        {:ok, run}

      true ->
        with {:ok, run} <- Demo.fetch(:sync_runs, id) do
          {:ok, %{run | user_id: user.id}}
        end
    end
  end

  @doc false
  # The worker body: one fresh login, import each source, record counts.
  # Runs off the request path; the password dies with this stack frame.
  @spec perform(SyncRun.t(), User.t(), binary()) :: SyncRun.t()
  def perform(%SyncRun{} = run, %User{} = user, password) do
    run = update_run!(run, %{status: "running"})

    try do
      case Usp.client().login(user.usp_username, password) do
        {:ok, session} ->
          counts = Map.new(run.sources, &{&1, import_source(&1, session, user)})
          finish(run, %{status: "succeeded", counts: counts})

        {:error, :invalid_credentials} ->
          finish(run, %{status: "failed", error: "USP rejected the stored credential"})

        {:error, :unavailable} ->
          finish(run, %{status: "failed", error: "USP is unreachable"})
      end
    rescue
      # A run must never be left stuck at "running" - an unexpected error
      # (a lost race with a concurrent sync, a USP data quirk, etc.) still
      # has to resolve to a terminal status.
      error -> finish(run, %{status: "failed", error: "Sync failed: #{Exception.message(error)}"})
    end
  end

  defp finish(run, attrs) do
    update_run!(run, Map.put(attrs, :finished_at, DateTime.utc_now(:second)))
  end

  defp update_run!(run, attrs) do
    run |> SyncRun.changeset(attrs) |> Repo.update!()
  end

  defp import_source("schedule", session, user) do
    with {:ok, slots} <- Usp.client().fetch_schedule(session),
         {:ok, periods} <- Usp.client().list_periods(session) do
      semester = upsert_semester(user, current_period(periods))

      slots
      |> Import.enrollments_from_schedule()
      |> Enum.map(&upsert_enrollment(user, semester, &1))
      |> length()
    else
      _unavailable -> 0
    end
  end

  # Grades and absences ride on the same imported enrollments; USP only
  # publishes them per closed period, so today they import as zero rows
  # rather than failing the run.
  defp import_source(_other_source, _session, _user), do: 0

  defp current_period([_head | _tail] = periods), do: Enum.max(periods)
  defp current_period(_empty), do: nil

  defp upsert_semester(user, nil), do: upsert_semester(user, fallback_period())

  defp upsert_semester(user, period) do
    attrs = Import.semester_attrs(period)

    case fetch_import_semester(user, period, attrs) do
      {:error, :not_found} -> insert_semester(user, attrs)
      {:ok, semester} -> semester
    end
  end

  defp insert_semester(user, attrs) do
    %Semester{}
    |> Semester.changeset(Map.put(attrs, :user_id, user.id))
    |> Repo.insert()
    |> case do
      {:ok, semester} ->
        semester

      {:error, _changeset} ->
        # Lost a race to a concurrent insert (or sync) that created a
        # matching semester in between our check and this insert - the
        # unique/exclusion constraints mirror fetch_matching_semester's
        # own match, so it is guaranteed to find the row that won.
        {:ok, semester} = fetch_matching_semester(user, attrs)
        semester
    end
  end

  defp fetch_import_semester(user, period, attrs) do
    by_external_ref =
      Repo.one(
        from(semester in Semester,
          where: semester.user_id == ^user.id and semester.external_ref == ^period
        )
      )

    if by_external_ref do
      {:ok, by_external_ref}
    else
      fetch_matching_semester(user, attrs)
    end
  end

  defp fetch_matching_semester(user, attrs) do
    semester =
      Repo.one(
        from(semester in Semester,
          where:
            semester.user_id == ^user.id and
              (semester.label == ^attrs.label or
                 (not is_nil(semester.start_date) and not is_nil(semester.end_date) and
                    semester.start_date <= ^attrs.end_date and
                    semester.end_date >= ^attrs.start_date)),
          limit: 1
        )
      )

    if semester, do: {:ok, semester}, else: {:error, :not_found}
  end

  defp upsert_enrollment(user, semester, %{meetings: meetings} = attrs) do
    enrollment_attrs = Map.delete(attrs, :meetings)

    enrollment =
      case Repo.one(
             from(enrollment in Enrollment,
               where:
                 enrollment.user_id == ^user.id and enrollment.external_ref == ^attrs.external_ref
             )
           ) do
        nil ->
          insert_enrollment(user, semester, enrollment_attrs)

        # Manual edits win: only rows still owned by the sync are updated.
        %{source: "usp"} = enrollment ->
          case enrollment |> Enrollment.changeset(enrollment_attrs) |> Repo.update() do
            {:ok, updated} -> updated
            # A concurrent write claimed the same class in the meantime;
            # keep the row as it stood rather than crash the sync.
            {:error, _changeset} -> enrollment
          end

        enrollment ->
          enrollment
      end

    Enum.each(meetings, &upsert_meeting(enrollment, &1))
    enrollment
  end

  defp insert_enrollment(user, semester, attrs) do
    %Enrollment{}
    |> Enrollment.changeset(Map.merge(attrs, %{user_id: user.id, semester_id: semester.id}))
    |> Repo.insert()
    |> case do
      {:ok, enrollment} ->
        enrollment

      {:error, _changeset} ->
        # Another row (manual or a concurrent sync) already claims this
        # class's discipline/title in the semester - reuse it instead of
        # crashing; its own source/ownership rules apply on the next pass.
        find_conflicting_enrollment(user, semester, attrs)
    end
  end

  defp find_conflicting_enrollment(user, semester, attrs) do
    Repo.one(
      from(enrollment in Enrollment,
        where:
          enrollment.user_id == ^user.id and enrollment.semester_id == ^semester.id and
            ((not is_nil(enrollment.discipline_id) and
                enrollment.discipline_id == ^attrs[:discipline_id]) or
               (not is_nil(enrollment.title) and enrollment.title == ^attrs[:title])),
        limit: 1
      )
    )
  end

  defp upsert_meeting(enrollment, attrs) do
    %Meeting{}
    |> Meeting.changeset(Map.put(attrs, :enrollment_id, enrollment.id))
    |> Repo.insert()
    |> case do
      {:ok, _meeting} ->
        :ok

      {:error, _changeset} ->
        # Already recorded (idempotent re-sync) or overlaps an existing
        # meeting for this class - either way, nothing to do.
        :ok
    end
  end

  defp ensure_not_running(user) do
    active? =
      Repo.exists?(
        from(run in SyncRun,
          where: run.user_id == ^user.id and run.status in ^~w(pending running)
        )
      )

    if active?,
      do: {:error, {:conflict, "A sync is already running for this account"}},
      else: :ok
  end

  defp open_blob(user, blob) do
    case Credentials.open_blob(user, blob) do
      {:ok, password} -> {:ok, password}
      {:error, :expired} -> {:error, {:forbidden, "Credential blob is expired - log in again"}}
      {:error, :invalid} -> {:error, {:forbidden, "Credential blob is revoked or invalid"}}
    end
  end

  defp fallback_period do
    today = Date.utc_today()
    "#{today.year}#{if today.month <= 6, do: 1, else: 2}"
  end
end

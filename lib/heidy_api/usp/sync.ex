defmodule HeidyApi.Usp.Sync do
  @moduledoc """
  Starts and tracks USP sync runs.

  `start/2` answers immediately with a `pending` run; the login + scrape +
  upsert happens in a supervised task so a slow USP never blocks a request.
  Syncs are serialized per user, and each run performs exactly one fresh
  USP login whose session dies with the run — nothing USP-side is cached.
  """

  alias HeidyApi.Accounts.User
  alias HeidyApi.Credentials
  alias HeidyApi.Usp.{Import, SyncRun}
  alias HeidyApi.{Ids, Page, Store, Usp}

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
      run =
        Store.put(:sync_runs, %SyncRun{
          id: Ids.generate(),
          user_id: user.id,
          sources: attrs.sources,
          semester_id: attrs[:semester_id],
          started_at: DateTime.utc_now(:second)
        })

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
    Store.list(:sync_runs)
    |> Enum.filter(&(&1.user_id == user.id))
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
    case Store.fetch(:sync_runs, id) do
      {:ok, %SyncRun{user_id: owner} = run} ->
        if Store.get(:sync_runs, id) == nil or owner == user.id,
          do: {:ok, %{run | user_id: user.id}},
          else: {:error, :not_found}

      {:error, :not_found} ->
        {:error, :not_found}
    end
  end

  @doc false
  # The worker body: one fresh login, import each source, record counts.
  # Runs off the request path; the password dies with this stack frame.
  @spec perform(SyncRun.t(), User.t(), binary()) :: SyncRun.t()
  def perform(%SyncRun{} = run, %User{} = user, password) do
    run = Store.put(:sync_runs, %{run | status: "running"})

    case Usp.client().login(user.usp_username, password) do
      {:ok, session} ->
        counts = Map.new(run.sources, &{&1, import_source(&1, session, user)})
        finish(run, %{status: "succeeded", counts: counts})

      {:error, :invalid_credentials} ->
        finish(run, %{status: "failed", error: "USP rejected the stored credential"})

      {:error, :unavailable} ->
        finish(run, %{status: "failed", error: "USP is unreachable"})
    end
  end

  defp finish(run, attrs) do
    Store.put(:sync_runs, struct!(run, Map.put(attrs, :finished_at, DateTime.utc_now(:second))))
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

    existing =
      Enum.find(Store.list(:semesters), fn semester ->
        semester.user_id == user.id and semester.external_ref == period
      end)

    case existing do
      nil ->
        Store.put(
          :semesters,
          struct!(
            %HeidyApi.Planner.Semester{id: Ids.generate(), user_id: user.id, label: nil},
            attrs
          )
        )

      semester ->
        semester
    end
  end

  defp upsert_enrollment(user, semester, %{meetings: meetings} = attrs) do
    enrollment_attrs = Map.delete(attrs, :meetings)

    existing =
      Enum.find(Store.list(:enrollments), fn enrollment ->
        enrollment.user_id == user.id and enrollment.external_ref == attrs.external_ref
      end)

    enrollment =
      case existing do
        nil ->
          Store.put(
            :enrollments,
            struct!(
              %HeidyApi.Planner.Enrollment{
                id: Ids.generate(),
                user_id: user.id,
                semester_id: semester.id
              },
              enrollment_attrs
            )
          )

        # Manual edits win: only rows still owned by the sync are updated.
        %{source: "usp"} = enrollment ->
          Store.put(:enrollments, struct!(enrollment, enrollment_attrs))

        enrollment ->
          enrollment
      end

    Enum.each(meetings, &upsert_meeting(enrollment, &1))
    enrollment
  end

  defp upsert_meeting(enrollment, attrs) do
    meeting =
      struct!(
        %HeidyApi.Planner.Meeting{
          id: Ids.generate(),
          enrollment_id: enrollment.id,
          day_of_week: nil,
          starts_at: nil,
          ends_at: nil
        },
        attrs
      )

    duplicate? =
      Enum.any?(Store.list(:meetings), fn existing ->
        existing.enrollment_id == enrollment.id and
          existing.day_of_week == meeting.day_of_week and
          existing.starts_at == meeting.starts_at
      end)

    unless duplicate?, do: Store.put(:meetings, meeting)
  end

  defp ensure_not_running(user) do
    active? =
      Enum.any?(Store.list(:sync_runs), fn run ->
        run.user_id == user.id and SyncRun.active?(run)
      end)

    if active?,
      do: {:error, {:conflict, "A sync is already running for this account"}},
      else: :ok
  end

  defp open_blob(user, blob) do
    case Credentials.open_blob(user, blob) do
      {:ok, password} -> {:ok, password}
      {:error, :expired} -> {:error, {:forbidden, "Credential blob is expired — log in again"}}
      {:error, :invalid} -> {:error, {:forbidden, "Credential blob is revoked or invalid"}}
    end
  end

  defp fallback_period do
    today = Date.utc_today()
    "#{today.year}#{if today.month <= 6, do: 1, else: 2}"
  end
end

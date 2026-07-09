defmodule HeidyApi.Usp.SyncRun do
  @moduledoc """
  One attempt to import data from USP. Returned immediately as `pending`;
  a supervised worker moves it through `running` to `succeeded`/`failed`.
  """

  @statuses ~w(pending running succeeded failed)
  @sources ~w(schedule grades absences)

  use HeidyApi.Schema

  import Ecto.Changeset

  alias HeidyApi.Ids

  schema "sync_runs" do
    field(:user_id, :binary_id)
    field(:sources, {:array, :string})
    field(:semester_id, :binary_id)
    field(:error, :string)
    field(:started_at, :utc_datetime)
    field(:finished_at, :utc_datetime)
    field(:status, :string, default: "pending")
    field(:counts, :map, default: %{})

    timestamps(type: :utc_datetime)
  end

  @type t :: %__MODULE__{}

  @spec statuses() :: [String.t()]
  def statuses, do: @statuses

  @doc "The data sources a sync can import."
  @spec sources() :: [String.t()]
  def sources, do: @sources

  @spec active?(t()) :: boolean()
  def active?(%__MODULE__{status: status}), do: status in ~w(pending running)

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(run, attrs) do
    run
    |> cast(attrs, [
      :id,
      :user_id,
      :sources,
      :semester_id,
      :status,
      :counts,
      :error,
      :started_at,
      :finished_at
    ])
    |> put_new_id()
    |> validate_required([:id, :user_id, :sources, :status])
    |> validate_subset(:sources, @sources)
    |> validate_inclusion(:status, @statuses)
  end

  defp put_new_id(changeset) do
    case get_field(changeset, :id) do
      nil -> put_change(changeset, :id, Ids.generate())
      _id -> changeset
    end
  end
end

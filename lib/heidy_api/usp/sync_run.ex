defmodule HeidyApi.Usp.SyncRun do
  @moduledoc """
  One attempt to import data from USP. Returned immediately as `pending`;
  a supervised worker moves it through `running` to `succeeded`/`failed`.
  """

  @statuses ~w(pending running succeeded failed)
  @sources ~w(schedule grades absences)

  @enforce_keys [:id, :user_id, :sources]
  defstruct [
    :id,
    :user_id,
    :sources,
    :semester_id,
    :error,
    :started_at,
    :finished_at,
    status: "pending",
    counts: %{}
  ]

  @type t :: %__MODULE__{
          id: String.t(),
          user_id: String.t(),
          sources: [String.t()],
          semester_id: String.t() | nil,
          error: String.t() | nil,
          started_at: DateTime.t() | nil,
          finished_at: DateTime.t() | nil,
          status: String.t(),
          counts: %{optional(String.t()) => non_neg_integer()}
        }

  @spec statuses() :: [String.t()]
  def statuses, do: @statuses

  @doc "The data sources a sync can import."
  @spec sources() :: [String.t()]
  def sources, do: @sources

  @spec active?(t()) :: boolean()
  def active?(%__MODULE__{status: status}), do: status in ~w(pending running)
end

defmodule HeidyApi.Planner.Task do
  @moduledoc "Something the student plans to do, optionally tied to a class."

  @kinds ~w(assignment exam project reading other)
  @statuses ~w(todo doing done)
  @priorities ~w(low normal high)

  @enforce_keys [:id, :user_id, :title]
  defstruct [
    :id,
    :user_id,
    :enrollment_id,
    :title,
    :notes,
    :due_at,
    kind: "assignment",
    status: "todo",
    priority: "normal",
    source: "manual"
  ]

  @type t :: %__MODULE__{
          id: String.t(),
          user_id: String.t(),
          enrollment_id: String.t() | nil,
          title: String.t(),
          notes: String.t() | nil,
          due_at: DateTime.t() | nil,
          kind: String.t(),
          status: String.t(),
          priority: String.t(),
          source: String.t()
        }

  @spec kinds() :: [String.t()]
  def kinds, do: @kinds

  @spec statuses() :: [String.t()]
  def statuses, do: @statuses

  @spec priorities() :: [String.t()]
  def priorities, do: @priorities
end

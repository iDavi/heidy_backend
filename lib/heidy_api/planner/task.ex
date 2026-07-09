defmodule HeidyApi.Planner.Task do
  @moduledoc "Something the student plans to do, optionally tied to a class."

  @kinds ~w(assignment exam project reading other)
  @statuses ~w(todo doing done)
  @priorities ~w(low normal high)

  use HeidyApi.Schema

  import Ecto.Changeset
  import HeidyApi.Changeset, only: [put_new_id: 1]

  schema "tasks" do
    field(:user_id, :binary_id)
    field(:enrollment_id, :binary_id)
    field(:title, :string)
    field(:notes, :string)
    field(:due_at, :utc_datetime)
    field(:kind, :string, default: "assignment")
    field(:status, :string, default: "todo")
    field(:priority, :string, default: "normal")
    field(:source, :string, default: "manual")

    timestamps(type: :utc_datetime)
  end

  @type t :: %__MODULE__{}

  @spec kinds() :: [String.t()]
  def kinds, do: @kinds

  @spec statuses() :: [String.t()]
  def statuses, do: @statuses

  @spec priorities() :: [String.t()]
  def priorities, do: @priorities

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(task, attrs) do
    task
    |> cast(attrs, [
      :id,
      :user_id,
      :enrollment_id,
      :title,
      :notes,
      :due_at,
      :kind,
      :status,
      :priority,
      :source
    ])
    |> put_new_id()
    |> validate_required([:id, :user_id, :title])
    |> validate_length(:title, max: 160)
    |> validate_length(:notes, max: 2_000)
    |> validate_inclusion(:kind, @kinds)
    |> validate_inclusion(:status, @statuses)
    |> validate_inclusion(:priority, @priorities)
    |> validate_inclusion(:source, ~w(manual usp))
  end
end

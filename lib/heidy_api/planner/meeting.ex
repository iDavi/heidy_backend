defmodule HeidyApi.Planner.Meeting do
  @moduledoc "A recurring weekly time slot of a class (wall-clock time + weekday)."

  use HeidyApi.Schema

  import Ecto.Changeset

  alias HeidyApi.Ids

  schema "meetings" do
    field(:enrollment_id, :binary_id)
    field(:day_of_week, :integer)
    field(:starts_at, :time)
    field(:ends_at, :time)
    field(:location, :string)

    timestamps(type: :utc_datetime)
  end

  @type t :: %__MODULE__{}

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(meeting, attrs) do
    meeting
    |> cast(attrs, [:id, :enrollment_id, :day_of_week, :starts_at, :ends_at, :location])
    |> put_new_id()
    |> validate_required([:id, :enrollment_id, :day_of_week, :starts_at, :ends_at])
    |> validate_number(:day_of_week, greater_than_or_equal_to: 1, less_than_or_equal_to: 7)
    |> validate_length(:location, max: 120)
    |> validate_time_order()
  end

  @doc "Whether two meetings occupy overlapping time on the same weekday."
  @spec overlaps?(t(), t()) :: boolean()
  def overlaps?(%__MODULE__{} = a, %__MODULE__{} = b) do
    a.day_of_week == b.day_of_week and
      Time.compare(a.starts_at, b.ends_at) == :lt and
      Time.compare(b.starts_at, a.ends_at) == :lt
  end

  defp validate_time_order(changeset) do
    starts_at = get_field(changeset, :starts_at)
    ends_at = get_field(changeset, :ends_at)

    if is_struct(starts_at, Time) and is_struct(ends_at, Time) and
         Time.compare(ends_at, starts_at) != :gt do
      add_error(changeset, :ends_at, "must be after starts_at")
    else
      changeset
    end
  end

  defp put_new_id(changeset) do
    case get_field(changeset, :id) do
      nil -> put_change(changeset, :id, Ids.generate())
      _id -> changeset
    end
  end
end

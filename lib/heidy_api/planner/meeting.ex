defmodule HeidyApi.Planner.Meeting do
  @moduledoc "A recurring weekly time slot of a class (wall-clock time + weekday)."

  @enforce_keys [:id, :enrollment_id, :day_of_week, :starts_at, :ends_at]
  defstruct [:id, :enrollment_id, :day_of_week, :starts_at, :ends_at, :location]

  @type t :: %__MODULE__{
          id: String.t(),
          enrollment_id: String.t(),
          day_of_week: 1..7,
          starts_at: Time.t(),
          ends_at: Time.t(),
          location: String.t() | nil
        }

  @doc "Whether two meetings occupy overlapping time on the same weekday."
  @spec overlaps?(t(), t()) :: boolean()
  def overlaps?(%__MODULE__{} = a, %__MODULE__{} = b) do
    a.day_of_week == b.day_of_week and
      Time.compare(a.starts_at, b.ends_at) == :lt and
      Time.compare(b.starts_at, a.ends_at) == :lt
  end
end

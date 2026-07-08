defmodule HeidyApi.Planner.Absence do
  @moduledoc "Missed class time for an enrollment on a given date."

  @enforce_keys [:id, :enrollment_id, :date]
  defstruct [:id, :enrollment_id, :date, :note, count: 1, source: "manual", external_ref: nil]

  @type t :: %__MODULE__{
          id: String.t(),
          enrollment_id: String.t(),
          date: Date.t(),
          note: String.t() | nil,
          count: pos_integer(),
          source: String.t(),
          external_ref: String.t() | nil
        }
end

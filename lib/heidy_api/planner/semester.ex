defmodule HeidyApi.Planner.Semester do
  @moduledoc "An academic period the student plans against (e.g. `2026.1`)."

  @enforce_keys [:id, :user_id, :label]
  defstruct [
    :id,
    :user_id,
    :label,
    :start_date,
    :end_date,
    active: true,
    source: "manual",
    external_ref: nil
  ]

  @type t :: %__MODULE__{
          id: String.t(),
          user_id: String.t(),
          label: String.t(),
          start_date: Date.t() | nil,
          end_date: Date.t() | nil,
          active: boolean(),
          source: String.t(),
          external_ref: String.t() | nil
        }
end

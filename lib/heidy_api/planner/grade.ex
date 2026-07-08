defmodule HeidyApi.Planner.Grade do
  @moduledoc "One graded assessment of a class (e.g. `P1`, score 8.5 of 10)."

  @enforce_keys [:id, :enrollment_id, :label]
  defstruct [
    :id,
    :enrollment_id,
    :label,
    :score,
    max_score: 10.0,
    weight: 1.0,
    source: "manual",
    external_ref: nil
  ]

  @type t :: %__MODULE__{
          id: String.t(),
          enrollment_id: String.t(),
          label: String.t(),
          score: number() | nil,
          max_score: number(),
          weight: number(),
          source: String.t(),
          external_ref: String.t() | nil
        }
end

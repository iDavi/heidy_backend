defmodule HeidyApi.Planner.Enrollment do
  @moduledoc """
  A class the student takes in a semester — added by hand or imported from
  USP. Provenance is first-class: `source` says who created the row and
  `external_ref` lets a re-sync upsert instead of duplicating.
  """

  @enforce_keys [:id, :user_id, :semester_id]
  defstruct [
    :id,
    :user_id,
    :semester_id,
    :discipline_id,
    :title,
    :professor,
    :credits,
    :color,
    :absence_limit,
    :external_ref,
    source: "manual",
    meetings: []
  ]

  @type t :: %__MODULE__{
          id: String.t(),
          user_id: String.t(),
          semester_id: String.t(),
          discipline_id: String.t() | nil,
          title: String.t() | nil,
          professor: String.t() | nil,
          credits: non_neg_integer() | nil,
          color: String.t() | nil,
          absence_limit: non_neg_integer() | nil,
          external_ref: String.t() | nil,
          source: String.t(),
          meetings: [HeidyApi.Planner.Meeting.t()]
        }
end

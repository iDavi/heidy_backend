defmodule HeidyApi.Planner.AttendanceSummary do
  @moduledoc """
  The computed attendance position of a class: absences used, how many are
  left before the enrollment's limit, and a status that turns to `warning`
  at 80% of the limit and `exceeded` past it.
  """

  alias HeidyApi.Planner.Absence

  @warning_ratio 0.8

  @enforce_keys [:used, :limit, :remaining, :status]
  defstruct [:used, :limit, :remaining, :status]

  @type t :: %__MODULE__{
          used: non_neg_integer(),
          limit: non_neg_integer() | nil,
          remaining: non_neg_integer() | nil,
          status: String.t()
        }

  @spec compute(non_neg_integer() | nil, [Absence.t()]) :: t()
  def compute(limit, absences) do
    used = absences |> Enum.map(& &1.count) |> Enum.sum()

    %__MODULE__{
      used: used,
      limit: limit,
      remaining: limit && max(limit - used, 0),
      status: status(used, limit)
    }
  end

  defp status(_used, nil), do: "ok"

  defp status(used, limit) do
    cond do
      used > limit -> "exceeded"
      used >= limit * @warning_ratio -> "warning"
      true -> "ok"
    end
  end
end

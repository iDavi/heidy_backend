defmodule HeidyApi.Planner.GradeSummary do
  @moduledoc """
  The computed grade outlook of a class: weighted average so far, how much
  weight is still ungraded, and whether the student is on track to pass.

  Scores are normalized to a 0–10 scale; USP's passing average is 5.0.
  Weights are fractions of the course total (assumed 1.0 unless the graded
  weight already exceeds it).
  """

  alias HeidyApi.Planner.Grade

  @passing_average 5.0
  @scale 10.0

  @enforce_keys [:weighted_average, :graded_weight, :remaining_weight, :passing_average, :status]
  defstruct [:weighted_average, :graded_weight, :remaining_weight, :passing_average, :status]

  @type t :: %__MODULE__{
          weighted_average: float(),
          graded_weight: float(),
          remaining_weight: float(),
          passing_average: float(),
          status: String.t()
        }

  @spec compute([Grade.t()]) :: t()
  def compute(grades) do
    scored = Enum.filter(grades, &is_number(&1.score))
    graded_weight = scored |> Enum.map(& &1.weight) |> Enum.sum() |> to_float()
    total_weight = max(graded_weight, 1.0)
    remaining_weight = total_weight - graded_weight

    weighted_average =
      if graded_weight > 0 do
        earned = Enum.sum(Enum.map(scored, &(normalized(&1) * &1.weight)))
        Float.round(earned / graded_weight, 2)
      else
        0.0
      end

    %__MODULE__{
      weighted_average: weighted_average,
      graded_weight: Float.round(graded_weight, 2),
      remaining_weight: Float.round(remaining_weight, 2),
      passing_average: @passing_average,
      status: status(weighted_average, graded_weight, remaining_weight, total_weight)
    }
  end

  defp status(average, graded_weight, remaining_weight, total_weight) do
    cond do
      remaining_weight <= 0.0 and average >= @passing_average ->
        "passed"

      remaining_weight <= 0.0 ->
        "failed"

      required_remaining_average(average, graded_weight, remaining_weight, total_weight) > @scale ->
        "failed"

      average >= @passing_average ->
        "on_track"

      true ->
        "at_risk"
    end
  end

  # The average needed on the remaining weight to end at the passing line.
  defp required_remaining_average(average, graded_weight, remaining_weight, total_weight) do
    (@passing_average * total_weight - average * graded_weight) / remaining_weight
  end

  defp normalized(%Grade{score: score, max_score: max_score})
       when is_number(max_score) and max_score > 0 do
    score / max_score * @scale
  end

  defp normalized(%Grade{score: score}), do: to_float(score)

  defp to_float(value), do: value / 1
end

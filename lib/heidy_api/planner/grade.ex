defmodule HeidyApi.Planner.Grade do
  @moduledoc "One graded assessment of a class (e.g. `P1`, score 8.5 of 10)."

  use HeidyApi.Schema

  import Ecto.Changeset
  import HeidyApi.Changeset, only: [put_new_id: 1]

  schema "grades" do
    field(:enrollment_id, :binary_id)
    field(:label, :string)
    field(:score, :float)
    field(:max_score, :float, default: 10.0)
    field(:weight, :float, default: 1.0)
    field(:source, :string, default: "manual")
    field(:external_ref, :string)

    timestamps(type: :utc_datetime)
  end

  @type t :: %__MODULE__{}

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(grade, attrs) do
    grade
    |> cast(attrs, [
      :id,
      :enrollment_id,
      :label,
      :score,
      :max_score,
      :weight,
      :source,
      :external_ref
    ])
    |> put_new_id()
    |> validate_required([:id, :enrollment_id, :label])
    |> validate_length(:label, max: 80)
    |> validate_number(:score, greater_than_or_equal_to: 0)
    |> validate_number(:max_score, greater_than: 0)
    |> validate_number(:weight, greater_than: 0)
    |> validate_inclusion(:source, ~w(manual usp))
  end
end

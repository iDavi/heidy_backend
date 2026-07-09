defmodule HeidyApi.Planner.Enrollment do
  @moduledoc """
  A class the student takes in a semester — added by hand or imported from
  USP. Provenance is first-class: `source` says who created the row and
  `external_ref` lets a re-sync upsert instead of duplicating.
  """

  use HeidyApi.Schema

  import Ecto.Changeset
  import HeidyApi.Changeset, only: [put_new_id: 1]
  alias HeidyApi.Planner.Meeting

  schema "enrollments" do
    field(:user_id, :binary_id)
    field(:semester_id, :binary_id)
    field(:discipline_id, :binary_id)
    field(:title, :string)
    field(:professor, :string)
    field(:credits, :integer)
    field(:color, :string)
    field(:absence_limit, :integer)
    field(:external_ref, :string)
    field(:source, :string, default: "manual")

    has_many(:meetings, Meeting)

    timestamps(type: :utc_datetime)
  end

  @type t :: %__MODULE__{}

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(enrollment, attrs) do
    enrollment
    |> cast(attrs, [
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
      :source
    ])
    |> put_new_id()
    |> validate_required([:id, :user_id, :semester_id])
    |> validate_length(:title, max: 160)
    |> validate_length(:professor, max: 120)
    |> validate_number(:credits, greater_than_or_equal_to: 0)
    |> validate_number(:absence_limit, greater_than_or_equal_to: 0)
    |> validate_format(:color, ~r/^#[0-9a-fA-F]{6}$/)
    |> validate_inclusion(:source, ~w(manual usp))
  end
end

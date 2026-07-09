defmodule HeidyApi.Planner.Absence do
  @moduledoc "Missed class time for an enrollment on a given date."

  use HeidyApi.Schema

  import Ecto.Changeset

  alias HeidyApi.Ids

  schema "absences" do
    field(:enrollment_id, :binary_id)
    field(:date, :date)
    field(:note, :string)
    field(:count, :integer, default: 1)
    field(:source, :string, default: "manual")
    field(:external_ref, :string)

    timestamps(type: :utc_datetime)
  end

  @type t :: %__MODULE__{}

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(absence, attrs) do
    absence
    |> cast(attrs, [:id, :enrollment_id, :date, :note, :count, :source, :external_ref])
    |> put_new_id()
    |> validate_required([:id, :enrollment_id, :date])
    |> validate_number(:count, greater_than_or_equal_to: 1, less_than_or_equal_to: 10)
    |> validate_length(:note, max: 200)
    |> validate_inclusion(:source, ~w(manual usp))
  end

  defp put_new_id(changeset) do
    case get_field(changeset, :id) do
      nil -> put_change(changeset, :id, Ids.generate())
      _id -> changeset
    end
  end
end

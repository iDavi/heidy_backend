defmodule HeidyApi.Planner.Semester do
  @moduledoc "An academic period the student plans against (e.g. `2026.1`)."

  use HeidyApi.Schema

  import Ecto.Changeset

  alias HeidyApi.Ids

  schema "semesters" do
    field(:user_id, :binary_id)
    field(:label, :string)
    field(:start_date, :date)
    field(:end_date, :date)
    field(:active, :boolean, default: true)
    field(:source, :string, default: "manual")
    field(:external_ref, :string)

    timestamps(type: :utc_datetime)
  end

  @type t :: %__MODULE__{}

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(semester, attrs) do
    semester
    |> cast(attrs, [
      :id,
      :user_id,
      :label,
      :start_date,
      :end_date,
      :active,
      :source,
      :external_ref
    ])
    |> put_new_id()
    |> validate_required([:id, :user_id, :label])
    |> validate_length(:label, max: 20)
    |> validate_inclusion(:source, ~w(manual usp))
    |> validate_date_order()
  end

  defp validate_date_order(changeset) do
    start_date = get_field(changeset, :start_date)
    end_date = get_field(changeset, :end_date)

    if is_struct(start_date, Date) and is_struct(end_date, Date) and
         Date.compare(end_date, start_date) == :lt do
      add_error(changeset, :end_date, "must be on or after start_date")
    else
      changeset
    end
  end

  defp put_new_id(changeset) do
    case get_field(changeset, :id) do
      nil -> put_change(changeset, :id, Ids.generate())
      _id -> changeset
    end
  end
end

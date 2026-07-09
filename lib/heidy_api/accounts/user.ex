defmodule HeidyApi.Accounts.User do
  @moduledoc """
  A heidy identity. There is no heidy password: the account *is* the USP
  account, created automatically on the first successful USP login.
  """

  use HeidyApi.Schema

  import Ecto.Changeset
  import HeidyApi.Changeset, only: [put_new_id: 1]

  schema "users" do
    field(:usp_username, :string)
    field(:name, :string)
    field(:email, :string)
    field(:course_id, :binary_id)

    timestamps(type: :utc_datetime)
  end

  @type t :: %__MODULE__{}

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(user, attrs) do
    user
    |> cast(attrs, [:id, :usp_username, :name, :email, :course_id])
    |> put_new_id()
    |> validate_required([:id, :usp_username])
    |> validate_format(:usp_username, ~r/^\d{6,10}$/)
    |> validate_length(:name, max: 120)
    |> validate_format(:email, ~r/^[^\s@]+@[^\s@]+\.[^\s@]+$/)
    |> unique_constraint(:usp_username)
  end

  @spec profile_changeset(t(), map()) :: Ecto.Changeset.t()
  def profile_changeset(user, attrs) do
    user
    |> cast(attrs, [:name, :email, :course_id])
    |> validate_length(:name, max: 120)
    |> validate_format(:email, ~r/^[^\s@]+@[^\s@]+\.[^\s@]+$/)
  end
end

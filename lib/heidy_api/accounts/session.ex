defmodule HeidyApi.Accounts.Session do
  @moduledoc false

  use HeidyApi.Schema

  import Ecto.Changeset

  alias HeidyApi.Ids

  schema "sessions" do
    field(:user_id, :binary_id)
    field(:token_hash, :string)

    timestamps(type: :utc_datetime)
  end

  def changeset(session, attrs) do
    session
    |> cast(attrs, [:id, :user_id, :token_hash])
    |> put_new_id()
    |> validate_required([:id, :user_id, :token_hash])
    |> unique_constraint(:token_hash)
  end

  defp put_new_id(changeset) do
    case get_field(changeset, :id) do
      nil -> put_change(changeset, :id, Ids.generate())
      _id -> changeset
    end
  end
end

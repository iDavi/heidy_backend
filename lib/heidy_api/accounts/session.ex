defmodule HeidyApi.Accounts.Session do
  @moduledoc false

  use HeidyApi.Schema

  import Ecto.Changeset
  import HeidyApi.Changeset, only: [put_new_id: 1]

  schema "sessions" do
    field(:user_id, :binary_id)
    field(:token_hash, :string)
    field(:expires_at, :utc_datetime)

    timestamps(type: :utc_datetime)
  end

  def changeset(session, attrs) do
    session
    |> cast(attrs, [:id, :user_id, :token_hash, :expires_at])
    |> put_new_id()
    |> validate_required([:id, :user_id, :token_hash, :expires_at])
    |> unique_constraint(:token_hash)
  end
end

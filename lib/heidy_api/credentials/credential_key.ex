defmodule HeidyApi.Credentials.CredentialKey do
  @moduledoc false

  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:user_id, :binary_id, autogenerate: false}

  schema "credential_keys" do
    field(:key, :binary)
    field(:version, :integer, default: 1)

    timestamps(type: :utc_datetime)
  end

  def changeset(credential_key, attrs) do
    credential_key
    |> cast(attrs, [:user_id, :key, :version])
    |> validate_required([:user_id, :key, :version])
    |> validate_number(:version, greater_than: 0)
  end
end

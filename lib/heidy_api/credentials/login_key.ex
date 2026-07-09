defmodule HeidyApi.Credentials.LoginKey do
  @moduledoc "The public key clients seal the Senha Única to at login."

  @enforce_keys [:key_id, :alg, :public_key]
  defstruct [:key_id, :alg, :public_key]

  @type t :: %__MODULE__{key_id: String.t(), alg: String.t(), public_key: String.t()}
end

defmodule HeidyApi.Credentials.Blob do
  @moduledoc """
  The opaque credential blob handed to the client at login. The client can
  store it but never read it; the server can only open it again with the
  per-user vault key.
  """

  @enforce_keys [:blob, :expires_at]
  defstruct [:blob, :expires_at]

  @type t :: %__MODULE__{blob: String.t(), expires_at: DateTime.t()}
end

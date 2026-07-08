defmodule HeidyApi.Accounts.User do
  @moduledoc """
  A heidy identity. There is no heidy password: the account *is* the USP
  account, created automatically on the first successful USP login.
  """

  @enforce_keys [:id, :usp_username]
  defstruct [:id, :usp_username, :name, :email, :course_id]

  @type t :: %__MODULE__{
          id: String.t(),
          usp_username: String.t(),
          name: String.t() | nil,
          email: String.t() | nil,
          course_id: String.t() | nil
        }
end

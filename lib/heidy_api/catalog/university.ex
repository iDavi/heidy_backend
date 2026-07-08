defmodule HeidyApi.Catalog.University do
  @moduledoc "A university heidy integrates with (only USP in v1)."

  @enforce_keys [:id, :name]
  defstruct [:id, :name, :acronym, :country]

  @type t :: %__MODULE__{
          id: String.t(),
          name: String.t(),
          acronym: String.t() | nil,
          country: String.t() | nil
        }
end

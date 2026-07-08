defmodule HeidyApi.Catalog.Unit do
  @moduledoc "A teaching unit / institute of a university (e.g. ICMC, POLI)."

  @enforce_keys [:id, :university_id, :name]
  defstruct [:id, :university_id, :name, :acronym]

  @type t :: %__MODULE__{
          id: String.t(),
          university_id: String.t(),
          name: String.t(),
          acronym: String.t() | nil
        }
end

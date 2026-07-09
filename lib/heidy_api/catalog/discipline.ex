defmodule HeidyApi.Catalog.Discipline do
  @moduledoc "A canonical discipline in the catalog (USP code, name, credits)."

  @enforce_keys [:id, :code, :name]
  defstruct [:id, :unit_id, :code, :name, :credits]

  @type t :: %__MODULE__{
          id: String.t(),
          unit_id: String.t() | nil,
          code: String.t(),
          name: String.t(),
          credits: non_neg_integer() | nil
        }
end

defmodule HeidyApi.Catalog.Course do
  @moduledoc "A degree program offered by a unit."

  @enforce_keys [:id, :unit_id, :name]
  defstruct [:id, :unit_id, :name, :code]

  @type t :: %__MODULE__{
          id: String.t(),
          unit_id: String.t(),
          name: String.t(),
          code: String.t() | nil
        }
end

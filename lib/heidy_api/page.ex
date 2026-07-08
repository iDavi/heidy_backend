defmodule HeidyApi.Page do
  @moduledoc "A page of results plus the pagination metadata the API exposes."

  @enforce_keys [:items, :page, :page_size, :total]
  defstruct [:items, :page, :page_size, :total]

  @type t :: %__MODULE__{
          items: [term()],
          page: pos_integer(),
          page_size: pos_integer(),
          total: non_neg_integer()
        }

  @doc "Slices `items` into the requested page."
  @spec paginate([term()], pos_integer(), pos_integer()) :: t()
  def paginate(items, page, page_size) do
    %__MODULE__{
      items: Enum.slice(items, (page - 1) * page_size, page_size),
      page: page,
      page_size: page_size,
      total: length(items)
    }
  end
end

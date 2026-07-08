defmodule HeidyApi.Store do
  @moduledoc """
  Session-scoped, in-memory persistence — the stand-in until the
  database-backed repo lands.

  Records live in a public ETS table keyed by `{session, collection, id}`,
  where the session is the calling process. Each API session therefore sees
  an isolated copy of the data, which is exactly the isolation a real
  database transaction sandbox would give the contract suite.

  Reads fall back to `HeidyApi.Demo`: a well-formed id that was never
  written resolves to a deterministic demo record, so every endpoint is
  fully exercisable before real persistence exists. Ids in the reserved
  zero block (see `HeidyApi.Ids`) never resolve.
  """

  use GenServer

  alias HeidyApi.{Demo, Ids}

  @table __MODULE__

  @type collection :: atom()
  @type record :: %{:id => String.t(), optional(atom()) => term()}

  def start_link(_opts), do: GenServer.start_link(__MODULE__, nil, name: __MODULE__)

  @impl true
  def init(nil) do
    :ets.new(@table, [:named_table, :public, :set, read_concurrency: true])
    {:ok, nil}
  end

  @doc "Fetches a record, falling back to the demo dataset for unknown ids."
  @spec fetch(collection(), term()) :: {:ok, record()} | {:error, :not_found}
  def fetch(collection, id) do
    cond do
      not Ids.valid?(id) -> {:error, :not_found}
      record = get(collection, id) -> {:ok, record}
      Ids.reserved?(id) -> {:error, :not_found}
      true -> Demo.fetch(collection, id)
    end
  end

  @doc "Returns the stored record under `key`, or `nil`. No demo fallback."
  @spec get(collection(), term()) :: record() | nil
  def get(collection, key) do
    case :ets.lookup(@table, {session(), collection, key}) do
      [{_key, record}] -> record
      [] -> nil
    end
  end

  @doc "Lists every stored record in `collection` for the current session."
  @spec list(collection()) :: [record()]
  def list(collection) do
    @table
    |> :ets.match({{session(), collection, :_}, :"$1"})
    |> List.flatten()
  end

  @doc "Inserts or replaces a record, keyed by its `:id`."
  @spec put(collection(), record()) :: record()
  def put(collection, %{id: id} = record) do
    put(collection, id, record)
  end

  @doc "Inserts or replaces a record under an explicit key."
  @spec put(collection(), term(), term()) :: term()
  def put(collection, key, record) do
    :ets.insert(@table, {{session(), collection, key}, record})
    record
  end

  @doc "Removes a record. Deleting an absent record is a no-op."
  @spec delete(collection(), term()) :: :ok
  def delete(collection, key) do
    :ets.delete(@table, {session(), collection, key})
    :ok
  end

  defp session, do: self()
end

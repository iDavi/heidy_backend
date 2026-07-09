defmodule HeidyApi.Moodle.SessionCache do
  @moduledoc false

  use GenServer

  @table __MODULE__
  @ttl_ms :timer.minutes(10)

  def start_link(_opts), do: GenServer.start_link(__MODULE__, :ok, name: __MODULE__)

  @spec fetch(binary()) :: {:ok, HeidyApi.Moodle.Session.t()} | :miss
  def fetch(key) do
    now = System.monotonic_time(:millisecond)

    case :ets.lookup(@table, key) do
      [{^key, expires_at, session}] when expires_at > now ->
        {:ok, session}

      [{^key, _expires_at, _session}] ->
        :ets.delete(@table, key)
        :miss

      [] ->
        :miss
    end
  end

  @spec put(binary(), HeidyApi.Moodle.Session.t()) :: :ok
  def put(key, session) do
    expires_at = System.monotonic_time(:millisecond) + @ttl_ms
    :ets.insert(@table, {key, expires_at, session})
    :ok
  end

  @spec delete(binary()) :: :ok
  def delete(key) do
    :ets.delete(@table, key)
    :ok
  end

  @impl true
  def init(:ok) do
    :ets.new(@table, [:named_table, :public, :set, read_concurrency: true])
    {:ok, nil}
  end
end

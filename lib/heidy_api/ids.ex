defmodule HeidyApi.Ids do
  @moduledoc """
  UUID helpers for user-facing resource ids.

  The all-zero-prefixed block (`00000000-...`) is reserved: those ids are
  never issued, so they always resolve to "not found". This gives clients
  (and the contract suite) a well-known way to reference a missing record.
  """

  @uuid_format ~r/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i
  @reserved_prefix "00000000-"

  @doc "Whether `value` is a well-formed UUID string."
  @spec valid?(term()) :: boolean()
  def valid?(value) when is_binary(value), do: Regex.match?(@uuid_format, value)
  def valid?(_value), do: false

  @doc "Whether `id` falls in the reserved never-issued block."
  @spec reserved?(String.t()) :: boolean()
  def reserved?(id), do: String.starts_with?(id, @reserved_prefix)

  @doc "Generates a random (version 4) UUID."
  @spec generate() :: String.t()
  def generate do
    <<a::48, _::4, b::12, _::2, c::62>> = :crypto.strong_rand_bytes(16)

    <<a::48, 4::4, b::12, 2::2, c::62>>
    |> Base.encode16(case: :lower)
    |> unstage()
  end

  defp unstage(<<a::binary-8, b::binary-4, c::binary-4, d::binary-4, e::binary-12>>),
    do: "#{a}-#{b}-#{c}-#{d}-#{e}"
end

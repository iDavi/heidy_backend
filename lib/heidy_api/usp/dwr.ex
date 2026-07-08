defmodule HeidyApi.Usp.Dwr do
  @moduledoc """
  A minimal client for DWR "plaincall" remoting — the AJAX protocol behind
  JupiterWeb's dynamic pages.

  A call is a `text/plain` POST of `key=value` lines against
  `dwr/call/plaincall/<Script>.<method>.dwr`; the reply is a JavaScript
  snippet that invokes `handleCallback` with the result as a JS object
  literal. This module builds the request body and turns the reply back
  into plain Elixir data (`parse/1`), so callers never touch the mess.
  """

  @typedoc "A parsed DWR payload: JSON-ish data decoded to Elixir terms."
  @type payload ::
          nil
          | boolean()
          | number()
          | String.t()
          | [payload()]
          | %{optional(String.t()) => payload()}

  @doc "Builds the request body for one plaincall invocation."
  @spec call_body(String.t(), String.t(), [String.t()], String.t(), String.t() | nil) ::
          String.t()
  def call_body(script, method, params, page, dwr_id) do
    param_lines =
      params
      |> Enum.with_index()
      |> Enum.map(fn {value, index} -> "c0-param#{index}=string:#{value}" end)

    lines =
      [
        "callCount=1",
        "nextReverseAjaxIndex=0",
        "c0-scriptName=#{script}",
        "c0-methodName=#{method}",
        "c0-id=0"
      ] ++
        param_lines ++
        [
          "batchId=0",
          "instanceId=0",
          "page=#{URI.encode_www_form(page)}",
          "scriptSessionId=#{session_id(dwr_id)}"
        ]

    Enum.join(lines, "\n") <> "\n"
  end

  @doc "Extracts and decodes the result of a plaincall reply."
  @spec parse(String.t()) :: {:ok, payload()} | {:error, {:dwr, String.t()}}
  def parse(body) do
    cond do
      captures = Regex.run(~r/handleCallback\("[^"]*","[^"]*",(.*)\);\s*\}\)\(\);/s, body) ->
        captures |> Enum.at(1) |> decode_literal()

      String.contains?(body, "handleException") ->
        {:error, {:dwr, "remote exception"}}

      true ->
        {:error, {:dwr, "unrecognized reply"}}
    end
  end

  # DWR pages pair a server-generated id with a client page id.
  defp session_id(nil), do: ""
  defp session_id(dwr_id), do: "#{dwr_id}/heidy-#{System.unique_integer([:positive])}"

  # The payload is a JS object literal, not JSON: keys are bare and dates
  # come as `new Date(ms)`. Quote the keys, inline the dates, then it *is*
  # JSON and Jason can do the heavy lifting.
  defp decode_literal(literal) do
    json =
      literal
      |> String.replace(~r/new Date\((\d+)\)/, "\\1")
      |> quote_bare_keys()

    case Jason.decode(json) do
      {:ok, data} -> {:ok, data}
      {:error, _reason} -> {:error, {:dwr, "unparsable payload"}}
    end
  end

  defp quote_bare_keys(literal), do: quote_bare_keys(literal, <<>>)

  defp quote_bare_keys(<<>>, acc), do: acc

  defp quote_bare_keys(<<?", rest::binary>>, acc) do
    {string, rest} = take_string(rest, <<?">>)
    quote_bare_keys(rest, acc <> string)
  end

  defp quote_bare_keys(<<char, rest::binary>>, acc)
       when char in ?a..?z or char in ?A..?Z or char == ?_ or char == ?$ do
    {word, rest} = take_word(rest, <<char>>)

    case rest do
      <<?:, _::binary>> -> quote_bare_keys(rest, acc <> "\"#{word}\"")
      _not_a_key -> quote_bare_keys(rest, acc <> word)
    end
  end

  defp quote_bare_keys(<<char, rest::binary>>, acc),
    do: quote_bare_keys(rest, <<acc::binary, char>>)

  defp take_string(<<?\\, escaped, rest::binary>>, acc),
    do: take_string(rest, <<acc::binary, ?\\, escaped>>)

  defp take_string(<<?", rest::binary>>, acc), do: {<<acc::binary, ?">>, rest}
  defp take_string(<<char, rest::binary>>, acc), do: take_string(rest, <<acc::binary, char>>)
  defp take_string(<<>>, acc), do: {acc, <<>>}

  defp take_word(<<char, rest::binary>>, acc)
       when char in ?a..?z or char in ?A..?Z or char in ?0..?9 or char == ?_ or char == ?$ do
    take_word(rest, <<acc::binary, char>>)
  end

  defp take_word(rest, acc), do: {acc, rest}
end

defmodule HeidyApiWeb.Params do
  @moduledoc """
  Declarative shape validation for controller params.

  A schema is a keyword list of `{field, opts}`; `validate/2` casts every
  field, collecting errors per field in the shape the API's validation
  envelope exposes:

      Params.validate(params,
        label: [type: :string, required: true, max: 20],
        page: [type: :integer, min: 1, default: 1]
      )
      #=> {:ok, %{label: "2026.2", page: 1}}
      #=> {:error, {:validation, %{"label" => ["can't be blank"]}}}

  Only *shape* lives here — business rules (existence, ownership,
  conflicts) belong to the contexts.
  """

  alias HeidyApi.Ids

  @type field_errors :: %{optional(String.t()) => [String.t()]}
  @type error :: {:error, {:validation, field_errors()}}
  @type schema :: [{atom(), keyword()}]

  @spec validate(map(), schema()) :: {:ok, map()} | error()
  def validate(params, schema) when is_map(params) do
    {casted, errors} =
      Enum.reduce(schema, {%{}, %{}}, fn {field, opts}, {casted, errors} ->
        name = Atom.to_string(field)

        case cast(Map.get(params, name), opts) do
          :skip -> {casted, errors}
          {:ok, value} -> {Map.put(casted, field, value), errors}
          {:error, message} -> {casted, Map.put(errors, name, List.wrap(message))}
        end
      end)

    if errors == %{}, do: {:ok, casted}, else: {:error, {:validation, errors}}
  end

  @doc "Fails with an error on `error_key` unless at least one field was given."
  @spec require_any({:ok, map()} | error(), [atom()], String.t()) :: {:ok, map()} | error()
  def require_any({:ok, casted} = ok, fields, error_key) do
    if Enum.any?(fields, &Map.has_key?(casted, &1)) do
      ok
    else
      {:error, {:validation, %{error_key => ["at least one field must be given"]}}}
    end
  end

  def require_any(error, _fields, _error_key), do: error

  @doc "Merges extra field errors (from cross-field checks) into a result."
  @spec merge_errors({:ok, map()} | error(), field_errors()) :: {:ok, map()} | error()
  def merge_errors(result, extra) when extra == %{}, do: result
  def merge_errors({:ok, _casted}, extra), do: {:error, {:validation, extra}}

  def merge_errors({:error, {:validation, fields}}, extra) do
    {:error, {:validation, Map.merge(fields, extra, fn _key, a, b -> a ++ b end)}}
  end

  @doc "Namespaces every error key under `prefix` (e.g. `envelope.key_id`)."
  @spec prefix_errors(error(), String.t()) :: error()
  def prefix_errors({:error, {:validation, fields}}, prefix) do
    {:error,
     {:validation, Map.new(fields, fn {key, messages} -> {"#{prefix}.#{key}", messages} end)}}
  end

  @doc "The pagination fields every list endpoint accepts."
  @spec pagination() :: schema()
  def pagination do
    [
      page: [type: :integer, min: 1, default: 1],
      page_size: [type: :integer, min: 1, max: 100, default: 25]
    ]
  end

  ## Casting

  defp cast(nil, opts) do
    cond do
      opts[:required] -> {:error, "can't be blank"}
      Keyword.has_key?(opts, :default) -> {:ok, opts[:default]}
      true -> :skip
    end
  end

  defp cast("", _opts), do: {:error, "can't be blank"}
  defp cast(value, opts), do: cast_type(opts[:type] || :string, value, opts)

  defp cast_type(:string, value, opts) when is_binary(value) do
    cond do
      opts[:max] && String.length(value) > opts[:max] ->
        {:error, "must be at most #{opts[:max]} characters"}

      opts[:format] && not Regex.match?(elem(opts[:format], 0), value) ->
        {:error, elem(opts[:format], 1)}

      true ->
        {:ok, value}
    end
  end

  defp cast_type(:integer, value, opts) when is_integer(value), do: check_bounds(value, opts)

  defp cast_type(:integer, value, opts) when is_binary(value) do
    case Integer.parse(value) do
      {integer, ""} -> check_bounds(integer, opts)
      _partial -> {:error, "must be an integer"}
    end
  end

  defp cast_type(:number, value, opts) when is_number(value), do: check_bounds(value, opts)

  defp cast_type(:number, value, opts) when is_binary(value) do
    case Float.parse(value) do
      {number, ""} -> check_bounds(number, opts)
      _partial -> {:error, "must be a number"}
    end
  end

  defp cast_type(:boolean, value, _opts) when is_boolean(value), do: {:ok, value}
  defp cast_type(:boolean, "true", _opts), do: {:ok, true}
  defp cast_type(:boolean, "false", _opts), do: {:ok, false}
  defp cast_type(:boolean, _value, _opts), do: {:error, "must be true or false"}

  defp cast_type(:uuid, value, _opts) do
    if Ids.valid?(value), do: {:ok, value}, else: {:error, "must be a valid UUID"}
  end

  defp cast_type(:date, value, _opts) when is_binary(value) do
    case Date.from_iso8601(value) do
      {:ok, date} -> {:ok, date}
      _invalid -> {:error, "must be an ISO 8601 date"}
    end
  end

  defp cast_type(:datetime, value, _opts) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, datetime, _offset} -> {:ok, datetime}
      _invalid -> {:error, "must be an ISO 8601 date-time"}
    end
  end

  defp cast_type(:time, value, _opts) when is_binary(value) do
    with true <- Regex.match?(~r/^\d{2}:\d{2}$/, value),
         [hour, minute] = String.split(value, ":"),
         {:ok, time} <- Time.new(String.to_integer(hour), String.to_integer(minute), 0) do
      {:ok, time}
    else
      _invalid -> {:error, "must be a time in HH:MM"}
    end
  end

  defp cast_type(:enum, value, opts) do
    if value in opts[:values],
      do: {:ok, value},
      else: {:error, "must be one of: #{Enum.join(opts[:values], ", ")}"}
  end

  defp cast_type({:array, :enum}, values, opts) when is_list(values) do
    cond do
      values == [] ->
        {:error, "can't be empty"}

      values != Enum.uniq(values) ->
        {:error, "must not contain duplicates"}

      not Enum.all?(values, &(&1 in opts[:values])) ->
        {:error, "must only contain: #{Enum.join(opts[:values], ", ")}"}

      true ->
        {:ok, values}
    end
  end

  defp cast_type({:array, :enum}, _value, _opts), do: {:error, "must be a list"}

  defp cast_type(:map, value, _opts) when is_map(value), do: {:ok, value}
  defp cast_type(:map, _value, _opts), do: {:error, "is invalid"}

  defp cast_type(_type, _value, _opts), do: {:error, "is invalid"}

  defp check_bounds(value, opts) do
    cond do
      opts[:min] && value < opts[:min] -> {:error, "must be at least #{opts[:min]}"}
      opts[:max] && value > opts[:max] -> {:error, "must be at most #{opts[:max]}"}
      opts[:gt] && value <= opts[:gt] -> {:error, "must be greater than #{opts[:gt]}"}
      true -> {:ok, value}
    end
  end
end

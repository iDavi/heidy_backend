defmodule HeidyApi.Changeset do
  @moduledoc false

  import Ecto.Changeset

  @type validation_error :: {:error, {:validation, map()}}

  @spec validation_error(Ecto.Changeset.t()) :: validation_error()
  def validation_error(%Ecto.Changeset{} = changeset) do
    {:error,
     {:validation,
      traverse_errors(changeset, fn {message, opts} ->
        Enum.reduce(opts, message, fn {key, value}, acc ->
          String.replace(acc, "%{#{key}}", to_string(value))
        end)
      end)}}
  end

  @spec apply_action(Ecto.Changeset.t(), atom()) ::
          {:ok, struct()} | {:error, {:validation, map()}}
  def apply_action(%Ecto.Changeset{} = changeset, action) do
    case Ecto.Changeset.apply_action(changeset, action) do
      {:ok, struct} -> {:ok, struct}
      {:error, changeset} -> validation_error(changeset)
    end
  end

  @spec normalize_result({:ok, struct()} | {:error, Ecto.Changeset.t()}) ::
          {:ok, struct()} | validation_error()
  def normalize_result({:ok, record}), do: {:ok, record}
  def normalize_result({:error, %Ecto.Changeset{} = changeset}), do: validation_error(changeset)

  @spec put_new_id(Ecto.Changeset.t()) :: Ecto.Changeset.t()
  def put_new_id(%Ecto.Changeset{} = changeset) do
    case get_field(changeset, :id) do
      nil -> put_change(changeset, :id, HeidyApi.Ids.generate())
      _id -> changeset
    end
  end
end

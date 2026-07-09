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
end

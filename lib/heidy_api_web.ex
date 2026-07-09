defmodule HeidyApiWeb do
  @moduledoc """
  The web entrypoint: `use HeidyApiWeb, :controller`.

  Controllers stay thin — authenticate, validate shape with
  `HeidyApiWeb.Params`, delegate to a context, render an envelope from
  `HeidyApiWeb.Responses`. Anything smarter belongs in `HeidyApi.*`.
  """

  def controller do
    quote do
      use Phoenix.Controller, formats: []

      import HeidyApiWeb.Responses
      import HeidyApiWeb.Controllers.Helpers

      alias HeidyApiWeb.Params

      action_fallback HeidyApiWeb.FallbackController
    end
  end

  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end

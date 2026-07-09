defmodule HeidyApiWeb.ErrorJSON do
  @moduledoc "Renders uncaught errors (bad routes, crashes) in the API's error envelope."

  def render(template, _assigns) do
    %{errors: %{detail: Phoenix.Controller.status_message_from_template(template)}}
  end
end

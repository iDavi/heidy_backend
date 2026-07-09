defmodule HeidyApiWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :heidy_api

  plug HeidyApiWeb.CorsPlug

  plug Plug.Parsers,
    parsers: [:json],
    pass: ["application/json"],
    json_decoder: Jason

  plug HeidyApiWeb.Router
end

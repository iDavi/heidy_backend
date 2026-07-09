import Config

config :phoenix, :json_library, Jason

config :heidy_api, HeidyApiWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Phoenix.Endpoint.Cowboy2Adapter,
  render_errors: [formats: [json: HeidyApiWeb.ErrorJSON], layout: false]

config :heidy_api,
  ecto_repos: [HeidyApi.Repo],
  cors_allowed_origins: ["http://localhost:5173", "http://127.0.0.1:5173"],
  usp_client: HeidyApi.Usp.Client.Jupiter,
  moodle_client: HeidyApi.Moodle.Client.Ediciplinas,
  vault: HeidyApi.Credentials.Vault.Local,
  session_ttl_days: 30,
  sync_async: true

import_config "#{config_env()}.exs"

import Config

config :heidy_api, HeidyApi.Repo,
  username: System.get_env("POSTGRES_USER") || "postgres",
  password: System.get_env("POSTGRES_PASSWORD") || "postgres",
  hostname: System.get_env("POSTGRES_HOST") || "localhost",
  database: System.get_env("POSTGRES_DB") || "heidy_api_dev",
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

config :heidy_api, HeidyApiWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4000],
  secret_key_base: "iEAybielIcJcXqGmM55PMYVdWtc94aFZC1cpDAOLQ0/S7didXlrJRHqQZ6PJDNsp",
  debug_errors: false,
  server: true

# Convenience bearer token so the API can be exercised from curl
# before real token issuance (database-backed sessions) lands.
config :heidy_api, demo_session_token: "dev-token"

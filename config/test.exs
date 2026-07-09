import Config

config :heidy_api, HeidyApi.Repo,
  username: System.get_env("POSTGRES_USER") || "postgres",
  password: System.get_env("POSTGRES_PASSWORD") || "postgres",
  hostname: System.get_env("POSTGRES_HOST") || "localhost",
  database: System.get_env("POSTGRES_DB") || "heidy_api_test",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10

config :heidy_api, HeidyApiWeb.Endpoint,
  secret_key_base: "aeIrgz9DM5jUMFyIkY3mUt91V25nOnjPuBHZ1oh0itopetJ8Cz2WKAAnj8oBmiXc",
  server: false

# The contract suite swaps every outward-facing integration for a stub:
# no HTTP leaves the test run and no real cryptography is exercised.
config :heidy_api,
  usp_client: HeidyApi.UspClientStub,
  moodle_client: HeidyApi.MoodleClientStub,
  vault: HeidyApi.VaultStub,
  session_token_secret: "test-session-token-secret",
  demo_session_token: "test-token",
  sync_async: false

config :logger, level: :warning

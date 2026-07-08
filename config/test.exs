import Config

config :heidy_api, HeidyApiWeb.Endpoint,
  secret_key_base: "aeIrgz9DM5jUMFyIkY3mUt91V25nOnjPuBHZ1oh0itopetJ8Cz2WKAAnj8oBmiXc",
  server: false

# The contract suite swaps every outward-facing integration for a stub:
# no HTTP leaves the test run and no real cryptography is exercised.
config :heidy_api,
  usp_client: HeidyApi.UspClientStub,
  vault: HeidyApi.VaultStub,
  demo_session_token: "test-token",
  sync_async: false

config :logger, level: :warning

import Config

config :heidy_api, HeidyApiWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4000],
  secret_key_base: "iEAybielIcJcXqGmM55PMYVdWtc94aFZC1cpDAOLQ0/S7didXlrJRHqQZ6PJDNsp",
  debug_errors: false,
  server: true

# Convenience bearer token so the API can be exercised from curl
# before real token issuance (database-backed sessions) lands.
config :heidy_api, demo_session_token: "dev-token"

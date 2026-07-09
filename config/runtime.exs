import Config

if config_env() == :prod do
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise "environment variable SECRET_KEY_BASE is missing"

  database_url =
    System.get_env("DATABASE_URL") ||
      raise "environment variable DATABASE_URL is missing"

  session_token_secret =
    System.get_env("SESSION_TOKEN_SECRET") ||
      raise "environment variable SESSION_TOKEN_SECRET is missing"

  config :heidy_api, session_token_secret: session_token_secret

  config :heidy_api, HeidyApi.Repo,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10")

  config :heidy_api, HeidyApiWeb.Endpoint,
    http: [ip: {0, 0, 0, 0}, port: String.to_integer(System.get_env("PORT") || "4000")],
    secret_key_base: secret_key_base,
    server: true
end

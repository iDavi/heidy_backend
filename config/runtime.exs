import Config

if config_env() == :prod do
  release_command? = System.get_env("RELEASE_COMMAND") == "1"
  fly_app_name = System.get_env("FLY_APP_NAME") || "heidy-backend"
  host = System.get_env("PHX_HOST") || "#{fly_app_name}.fly.dev"
  port = String.to_integer(System.get_env("PORT") || "4000")

  cors_allowed_origins =
    "CORS_ALLOWED_ORIGINS"
    |> System.get_env("*")
    |> String.split(",", trim: true)
    |> Enum.map(&String.trim/1)

  database_url =
    if release_command? do
      System.get_env("DIRECT_DATABASE_URL") || System.get_env("DATABASE_URL")
    else
      System.get_env("DATABASE_URL")
    end ||
      raise "environment variable DATABASE_URL is missing"

  database_host = database_url |> URI.parse() |> Map.get(:host)

  fly_private_db? =
    is_binary(database_host) and
      (String.ends_with?(database_host, ".internal") or
         String.ends_with?(database_host, ".flycast"))

  repo_config = [
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "8"),
    prepare: :unnamed
  ]

  repo_config =
    if System.get_env("ECTO_IPV6") in ~w(true 1) and fly_private_db? do
      Keyword.put(repo_config, :socket_options, [:inet6])
    else
      repo_config
    end

  config :heidy_api, HeidyApi.Repo, repo_config
  config :heidy_api, cors_allowed_origins: cors_allowed_origins

  unless release_command? do
    secret_key_base =
      System.get_env("SECRET_KEY_BASE") ||
        raise "environment variable SECRET_KEY_BASE is missing"

    session_token_secret =
      System.get_env("SESSION_TOKEN_SECRET") ||
        raise "environment variable SESSION_TOKEN_SECRET is missing"

    config :heidy_api, session_token_secret: session_token_secret

    config :heidy_api, HeidyApiWeb.Endpoint,
      url: [host: host, port: 443, scheme: "https"],
      http: [ip: {0, 0, 0, 0}, port: port],
      secret_key_base: secret_key_base,
      server: true
  end
end

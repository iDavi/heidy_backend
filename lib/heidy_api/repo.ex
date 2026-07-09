defmodule HeidyApi.Repo do
  use Ecto.Repo,
    otp_app: :heidy_api,
    adapter: Ecto.Adapters.Postgres
end

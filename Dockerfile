ARG ELIXIR_VERSION=1.18.3
ARG OTP_VERSION=27.0
ARG DEBIAN_VERSION=bookworm-20260610-slim

ARG BUILDER_IMAGE="hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-debian-${DEBIAN_VERSION}"
ARG RUNNER_IMAGE="debian:${DEBIAN_VERSION}"

FROM ${BUILDER_IMAGE} AS builder

ENV MIX_ENV=prod

RUN apt-get update -y && apt-get install -y --no-install-recommends build-essential git \
  && apt-get clean && rm -rf /var/lib/apt/lists/*

WORKDIR /app

RUN mix local.hex --force && mix local.rebar --force

COPY mix.exs mix.lock ./
RUN mix deps.get --only prod
RUN mkdir config

COPY config/config.exs config/prod.exs config/runtime.exs config/
RUN mix deps.compile

COPY lib lib
COPY priv priv
COPY rel rel

RUN mix compile
RUN mix release

FROM ${RUNNER_IMAGE}

RUN apt-get update -y && apt-get install -y --no-install-recommends libstdc++6 openssl libncurses6 ca-certificates \
  && apt-get clean && rm -rf /var/lib/apt/lists/*

WORKDIR /app

ENV MIX_ENV=prod
ENV LANG=C.UTF-8
ENV ECTO_IPV6=true
ENV ERL_AFLAGS="-proto_dist inet6_tcp"

COPY --from=builder /app/_build/prod/rel/heidy_api ./

EXPOSE 4000

CMD ["/app/bin/server"]

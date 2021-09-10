ARG CRYSTAL_VERSION=1.1.1
FROM crystallang/crystal:${CRYSTAL_VERSION}-alpine AS build
WORKDIR /app

RUN apk add --no-cache yaml-static

COPY shard.yml .
COPY shard.override.yml .
COPY shard.lock .

RUN shards install --static --ignore-crystal-version --production

COPY src src

RUN mkdir -p /app/bin

RUN shards build --release --static --error-trace --ignore-crystal-version

FROM alpine:3.14

WORKDIR /app

# Install bash, rethinkdb & python driver
RUN apk add --no-cache \
      apache2-utils \
      bash \
      coreutils \
      openssh \
      openssl \
      py3-pip \
    && \
    apk add --no-cache -X http://dl-cdn.alpinelinux.org/alpine/v3.12/community rethinkdb

RUN pip install rethinkdb

COPY scripts /app/scripts

COPY --from=build /app/bin /app/bin

ENV PATH="/app/bin:/app/scripts:${PATH}"

CMD ["/app/bin/start"]

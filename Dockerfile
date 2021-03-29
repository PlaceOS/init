FROM crystallang/crystal:1.0.0-alpine AS base
WORKDIR /app

RUN apk add --no-cache yaml-static

COPY shard.yml .
COPY shard.override.yml .
COPY shard.lock .

RUN shards install --static --ignore-crystal-version --production

COPY src src

RUN mkdir -p /app/bin

RUN shards build --static --error-trace --release --ignore-crystal-version

FROM alpine:3.12

WORKDIR /app

# Install bash, rethinkdb & python driver
RUN apk add --no-cache rethinkdb py-pip bash openssl openssh coreutils

RUN pip install rethinkdb

COPY scripts /app/scripts

COPY --from=base /app/bin /app/bin

ENV PATH="/app/bin:/app/scripts:${PATH}"

CMD ["/app/bin/start"]

FROM crystallang/crystal:0.36.1-alpine AS base

WORKDIR /app

COPY shard.yml .
COPY shard.override.yml .
COPY shard.lock .

RUN shards install --static

COPY src src

RUN mkdir -p /app/bin

RUN shards build --static --production --error-trace --release

FROM alpine:3.11

WORKDIR /app

# Install bash, rethinkdb & python driver
RUN apk add --no-cache rethinkdb py-pip bash openssl openssh coreutils

RUN pip install rethinkdb

COPY scripts /app/scripts

COPY --from=base /app/bin /app/bin

ENV PATH="/app/bin:/app/scripts:${PATH}"

CMD ["/app/bin/start"]

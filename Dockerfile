FROM crystallang/crystal:0.35.1-alpine AS base

WORKDIR /app

COPY shard.yml shard.yml
COPY shard.lock shard.lock

RUN shards install --static

COPY src src

RUN mkdir -p /app/bin

RUN shards build --static --production --error-trace --release

FROM alpine:3.11

WORKDIR /app

# Install bash, rethinkdb & python driver
RUN apk add --no-cache rethinkdb py-pip bash openssl openssh coreutils

RUN pip install rethinkdb

COPY --from=base /app/bin /app/bin

ENV PATH="/app/bin:${PATH}"

CMD ["/app/bin/start"]

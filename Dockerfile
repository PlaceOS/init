FROM crystallang/crystal:0.35.1-alpine AS base

WORKDIR /scripts

COPY shard.yml shard.yml
COPY shard.lock shard.lock

RUN shards install

COPY src src

RUN mkdir -p /scripts/bin
ENV PATH="/scripts/bin:${PATH}"

RUN shards build --static --production --error-trace --release

FROM alpine:3.11

# Install bash, rethinkdb & python driver
RUN apk add --no-cache rethinkdb py-pip bash openssl openssh coreutils

RUN pip install rethinkdb

COPY --from=base scripts/bin /scripts

COPY scripts/* /scripts

CMD ["/scripts/start"]

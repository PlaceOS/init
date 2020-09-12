FROM crystallang/crystal:0.35.1-alpine

WORKDIR /scripts

COPY shard.yml shard.yml
COPY shard.lock shard.lock

RUN shards install

COPY src src

RUN mkdir -p /scripts/bin
ENV PATH="/scripts/bin:${PATH}"

RUN shards build --static --production --error-trace --release

FROM alpine:3.11

# Install rethinkdb & python driver
RUN apk add --update rethinkdb py-pip
RUN pip install rethinkdb

COPY --from=0 /scripts/bin /scripts

CMD ["/scripts/start"]

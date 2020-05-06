FROM crystallang/crystal:0.34.0-alpine

WORKDIR /scripts

COPY shard.yml shard.yml

COPY shard.lock shard.lock

RUN shards install

COPY src src

RUN crystal build --error-trace --release -o bin/start src/start.cr

CMD ["/scripts/bin/start"]

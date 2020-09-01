FROM crystallang/crystal:0.35.1-alpine

# Install rethinkdb & python driver
RUN apk add --update rethinkdb py-pip
RUN pip install rethinkdb

WORKDIR /scripts

COPY Makefile Makefile

COPY shard.yml shard.yml

COPY shard.lock shard.lock

RUN shards install

COPY src src

RUN crystal build --error-trace --release -o start src/start.cr
RUN crystal build --error-trace --release -o backup src/backup.cr

CMD ["/scripts/start"]

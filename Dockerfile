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

RUN mkdir -p /scripts/bin
ENV PATH="/scripts/bin:${PATH}"

RUN shards build --production --error-trace --release

CMD ["/scripts/start"]

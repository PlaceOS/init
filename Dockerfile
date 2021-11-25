ARG CRYSTAL_VERSION=1.2.2
FROM crystallang/crystal:${CRYSTAL_VERSION}-alpine AS build
WORKDIR /app

RUN apk add --no-cache yaml-static

COPY shard.yml .
COPY shard.override.yml .
COPY shard.lock .

RUN shards install --static --ignore-crystal-version --production

COPY src src

RUN mkdir -p /app/bin

RUN shards build \
    --error-trace \
    --ignore-crystal-version \
    --release \
    --static

# TODO: Stuck on 3.12 as `rethinkdb` is no longer packaged.
FROM alpine:3.12

WORKDIR /app

# Install bash, rethinkdb & python driver
RUN apk add --no-cache \
        apache2-utils \
        bash \
        coreutils \
        openssh \
        openssl \
        py-pip \
        rethinkdb

RUN pip install --no-cache-dir "rethinkdb==2.4.8"

COPY scripts /app/scripts

COPY --from=build /app/bin /app/bin

ENV PATH="/app/bin:/app/scripts:${PATH}"

CMD ["/app/bin/start"]

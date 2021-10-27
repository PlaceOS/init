ARG CRYSTAL_VERSION=1.1.1
FROM crystallang/crystal:${CRYSTAL_VERSION}-alpine AS build
WORKDIR /app

RUN apk add --update --no-cache yaml-static

COPY shard.yml .
COPY shard.override.yml .
COPY shard.lock .

# hadolint ignore=DL3003
RUN shards install \
        --ignore-crystal-version \
        --production \
        --skip-postinstall \
        --static \
    && \
    ( \
        cd lib/sodium \
        && \
        PKG_CONFIG_PATH=$(which pkg-config) \
        bash build/libsodium_install.sh \
    )

COPY src src

RUN mkdir -p /app/bin

RUN shards build \
        --error-trace \
        --ignore-crystal-version \
        --production \
        --release \
        --static

# TODO: Stuck on 3.12 as `rethinkdb` is no longer packaged.
FROM alpine:3.12

WORKDIR /app

# Install bash, rethinkdb & python driver
RUN apk add --update --no-cache \
        apache2-utils>=2.4.51-r0 \
        apk-tools>=2.10.8-r0 \
        libcurl>=7.79.1-r0 \
        bash \
        coreutils \
        openssh \
        openssl \
        py-pip \
        rethinkdb

RUN pip install rethinkdb

COPY scripts /app/scripts

COPY --from=build /app/bin /app/bin

ENV PATH="/app/bin:/app/scripts:${PATH}"

CMD ["/app/bin/start"]

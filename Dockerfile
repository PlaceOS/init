ARG CRYSTAL_VERSION=1.2.1
FROM crystallang/crystal:${CRYSTAL_VERSION}-alpine AS build
WORKDIR /app

RUN apk add --update --no-cache \
        bash \
        openssl \
        yaml-static

COPY shard.yml .
COPY shard.override.yml .
COPY shard.lock .

# hadolint ignore=DL3003
RUN shards install \
        --ignore-crystal-version \
        --production \
        --skip-postinstall \
        --skip-executables \
    && \
    ( \
        cd lib/sodium \
        && \
        PKG_CONFIG_PATH=$(which pkg-config) \
        bash build/libsodium_install.sh \
    ) \
    && \
    ( \
       cd lib/exec_from \
       && \
       make bin && make run_file \
    )

COPY src src

RUN mkdir -p /app/bin

RUN shards build \
        --error-trace \
        --ignore-crystal-version \
        --production \
        --release \
        --skip-postinstall

SHELL ["/bin/ash", "-eo", "pipefail", "-c"]

# Extract binary dependencies
RUN for binary in "/app/*"; do \
        ldd "$binary" | \
        tr -s '[:blank:]' '\n' | \
        grep '^/' | \
        xargs -I % sh -c 'mkdir -p $(dirname deps%); cp % deps%;'; \
    done

# TODO: Stuck on 3.12 as `rethinkdb` is no longer packaged.
FROM alpine:3.12

WORKDIR /app

# Install bash, rethinkdb & python driver
RUN apk add --update --no-cache \
        apache2-utils>=2.4.51-r0 \
        apk-tools>=2.10.8-r0 \
        bash \
        coreutils \
        libcurl>=7.79.1-r0 \
        libsodium \
        openssh \
        openssl \
        py-pip \
        rethinkdb

RUN pip install --no-cache-dir \
        rethinkdb==2.4.8

COPY scripts /app/scripts

COPY --from=build /app/deps /
COPY --from=build /app/bin /app/bin

ENV PATH="/app/bin:/app/scripts:${PATH}"

CMD ["/app/bin/start"]

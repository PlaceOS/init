ARG CRYSTAL_VERSION=1.5.0
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
RUN for binary in /app/bin/*; do \
        ldd "$binary" | \
        tr -s '[:blank:]' '\n' | \
        grep '^/' | \
        xargs -I % sh -c 'mkdir -p $(dirname deps%); cp % deps%;'; \
    done

FROM alpine:latest

WORKDIR /app

# Install bash, rethinkdb & python driver
RUN apk add \
  --update \
  --no-cache \
  --repository=http://dl-cdn.alpinelinux.org/alpine/edge/main \
    expat \
    git

# Install bash, rethinkdb & python driver
RUN apk add \
  --update \
  --no-cache \
    'apache2-utils>=2.4.52-r0' \
    'apk-tools>=2.10.8-r0' \
    bash \
    coreutils \
    jq \
    'libcurl>=7.79.1-r0' \
    libsodium \
    openssh \
    openssl \
    py-pip

# TODO: Stuck on 3.12 as `rethinkdb` is no longer packaged.
RUN apk add \
  --repository=http://dl-cdn.alpinelinux.org/alpine/v3.12/community \
  --repository=http://dl-cdn.alpinelinux.org/alpine/v3.12/main \
    rethinkdb

RUN pip install \
  --no-cache-dir \
    rethinkdb==2.4.8 \
    'urllib3>=1.26.5'

RUN apk del py-pip

COPY scripts /app/scripts

COPY --from=build /app/deps /
COPY --from=build /app/bin /app/bin

ENV PATH="/app/bin:/app/scripts:${PATH}"

CMD ["/app/bin/start"]

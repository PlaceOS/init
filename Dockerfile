ARG CRYSTAL_VERSION=1.5.0
FROM alpine:3.16 as build
WORKDIR /app

# Add trusted CAs for communicating with external services
RUN apk add \
  --update \
  --no-cache \
    ca-certificates \
    yaml-dev \
    yaml-static \
    libxml2-dev \
    openssl-dev \
    openssl-libs-static \
    zlib-dev \
    zlib-static \
    tzdata

RUN update-ca-certificates

# Add crystal lang
# can look up packages here: https://pkgs.alpinelinux.org/packages?name=crystal
RUN apk add \
  --update \
  --no-cache \
  --repository=http://dl-cdn.alpinelinux.org/alpine/edge/main \
  --repository=http://dl-cdn.alpinelinux.org/alpine/edge/community \
    crystal \
    shards


# Install shards for caching
COPY shard.yml shard.yml
COPY shard.override.yml shard.override.yml
COPY shard.lock shard.lock

RUN shards install \
        --ignore-crystal-version \
        --production \
        --skip-postinstall \
        --skip-executables

COPY src src

RUN mkdir -p /app/bin

# Build init
# TODO:: build static binaries, no libxml2-static available
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

# Build a minimal docker image
FROM alpine:3.16

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
    openssh \
    openssl \
    py-pip

# TODO: Stuck on 3.12 as `rethinkdb` is no longer packaged.
RUN apk add \
  --update \
  --no-cache \
  --repository=http://dl-cdn.alpinelinux.org/alpine/v3.12/community \
  --repository=http://dl-cdn.alpinelinux.org/alpine/v3.12/main \
    rethinkdb

RUN pip install \
  --no-cache-dir \
    rethinkdb==2.4.8 \
    'urllib3>=1.26.5'

RUN apk del py-pip

# copy app
COPY scripts /app/scripts
COPY --from=build /app/deps /
COPY --from=build /app/bin /app/bin

ENV PATH="/app/bin:/app/scripts:${PATH}"

CMD ["/app/bin/start"]

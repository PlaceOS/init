ARG CRYSTAL_VERSION=latest

FROM placeos/crystal:$CRYSTAL_VERSION AS build
WORKDIR /app

# Install shards for caching
COPY shard.yml shard.yml
COPY shard.override.yml shard.override.yml
COPY shard.lock shard.lock
COPY spinner spinner

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
        --skip-postinstall

RUN crystal build -o bin/task src/sam.cr
SHELL ["/bin/ash", "-eo", "pipefail", "-c"]

# Extract binary dependencies
RUN for binary in /app/bin/*; do \
        ldd "$binary" | \
        tr -s '[:blank:]' '\n' | \
        grep '^/' | \
        xargs -I % sh -c 'mkdir -p $(dirname deps%); cp % deps%;'; \
    done

RUN git clone https://github.com/PlaceOS/models

# Build a minimal docker image
FROM alpine:3.21

WORKDIR /app

# Use more recent apk repos for security updates
RUN sed -i 's/3.21/3.22/g' /etc/apk/repositories && apk update && apk --no-cache --quiet upgrade

# Install bash, postgresql-client
RUN apk add \
  --update \
  --no-cache \
  tzdata \
  'apache2-utils>=2.4.52-r0' \
  expat \
  git \
  bash \
  jq \
  coreutils \
  'libcurl>=7.79.1-r0' \
  openssh \
  openssl \
  postgresql17-client

# copy app
COPY scripts /app/scripts
COPY --from=build /app/deps /
COPY --from=build /app/bin /app/bin
COPY --from=build /app/models/migration/db /app/db

ENV PATH="/app/bin:/app/scripts:${PATH}"

CMD ["/app/bin/start"]

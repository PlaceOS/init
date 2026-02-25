ARG CRYSTAL_VERSION=latest

FROM placeos/crystal:$CRYSTAL_VERSION AS build
WORKDIR /app

# Install package updates since image release
RUN apk update && apk --no-cache --quiet upgrade

# Update CA certificates
RUN update-ca-certificates

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
  wget \
  postgresql17-client

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
RUN shards build \
        --error-trace \
        --static \
        --ignore-crystal-version \
        --production \
        --skip-postinstall

RUN crystal build --static -o bin/task src/sam.cr
RUN crystal build --static -o bin/generate-secrets src/generate-secrets.cr
SHELL ["/bin/ash", "-eo", "pipefail", "-c"]

# Extract binary dependencies
RUN mkdir deps
RUN for binary in /app/bin/* /usr/bin/pg_dump /usr/bin/pg_restore /usr/bin/psql; do \
        [ -x "$binary" ] || continue; \
        ldd "$binary" | \
        tr -s '[:blank:]' '\n' | \
        grep '^/' | \
        xargs -I % sh -c 'mkdir -p $(dirname deps%); cp % deps%;'; \
    done

RUN git clone https://github.com/PlaceOS/models

# obtain busy box for file ops in scratch image
ARG TARGETARCH
RUN case "${TARGETARCH}" in \
      amd64) ARCH=x86_64 ;; \
      arm64) ARCH=armv8l ;; \
      *) echo "Unsupported arch: ${TARGETARCH}" && exit 1 ;; \
    esac && \
    wget --progress=dot:giga -O /busybox "https://busybox.net/downloads/binaries/1.31.0-defconfig-multiarch-musl/busybox-${ARCH}" && \
    chmod +x /busybox

# Create tmp directory with proper permissions
RUN rm -rf /tmp && mkdir -p /tmp && chmod 1777 /tmp

# Build a minimal docker image
FROM scratch
WORKDIR /app
ENV PATH=$PATH:/:/app/bin

# These are required for communicating with external services
COPY --from=build /etc/hosts /etc/hosts

# These provide certificate chain validation where communicating with external services over TLS
COPY --from=build /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
COPY --from=build /etc/gitconfig /etc/gitconfig
ENV SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt
ENV GIT_SSL_CAINFO=/etc/ssl/certs/ca-certificates.crt

# This is required for Timezone support
COPY --from=build /usr/share/zoneinfo/ /usr/share/zoneinfo/

COPY --from=build /busybox /bin/busybox
SHELL ["/bin/busybox", "sh", "-euo", "pipefail", "-c"]

# chmod for setting permissions on /tmp
COPY --from=build /tmp /tmp

# shellcheck disable=SC1008 # ignore false positive - "This shebang was unrecognized"
RUN /bin/busybox chmod -R a+rwX /tmp
# shellcheck disable=SC1008 # ignore false positive - "This shebang was unrecognized"
RUN /bin/busybox rm -rf /bin/busybox

# Copy the app into place
COPY --from=build /app/deps /
COPY --from=build /app/bin /app/bin
COPY --from=build /usr/bin/pg_dump /pg_dump
COPY --from=build /usr/bin/pg_restore /pg_restore
COPY --from=build /usr/bin/psql /psql
COPY --from=build /app/models/migration/db /app/db

CMD ["/app/bin/start"]

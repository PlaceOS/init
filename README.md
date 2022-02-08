# PlaceOS Init Container

[![Build](https://github.com/PlaceOS/init/actions/workflows/build.yml/badge.svg)](https://github.com/PlaceOS/init/actions/workflows/build.yml)
[![CI](https://github.com/PlaceOS/init/actions/workflows/ci.yml/badge.svg)](https://github.com/PlaceOS/init/actions/workflows/ci.yml)

A set of scripts for initialization of PlaceOS.

## Usage

The scripts are methods wrapped by a [sam.cr](https://github.com/imdrasil/sam.cr) interface. Most use named arguments which are used as [described here](https://github.com/imdrasil/sam.cr#tasks-with-arguments).

Execute scripts as one-off container jobs.

## Example

```bash
# Create a set of placeholder documents
docker-compose run --no-deps -it init task create:placeholder
```

```bash
# Create an Authority
docker-compose run --no-deps -it init task create:authority domain="localhost:8080"
```

```bash
# Create a User
docker-compose run --no-deps -it init task create:user \
    authority_id="s0mek1nd4UUID" \
    email="support@place.tech" \
    username="burger" \
    password="burgerR00lz" \
    sys_admin=true \
    support=true
```

```bash
# Restore to a database backup from S3
docker-compose run --no-deps -it init task restore:rethinkdb \
    rethinkdb_host=$RETHINKDB_HOST \
    rethinkdb_port=$RETHINKDB_PORT \
    force_restore=$RETHINKDB_FORCE_RESTORE \
    aws_region=$AWS_REGION \
    aws_s3_bucket=$AWS_S3_BUCKET \
    aws_s3_object=$AWS_S3_BUCKET \
    aws_key=$AWS_KEY \
    aws_secret=$AWS_SECRET
```

```bash
# Restore to a database backup from filesystem
docker-compose run --no-deps \
    -v /etc/placeos/rethinkdb_dump_2020-07-14T14_26_19.tar.gz:/rethink-dump.tar.gz:Z \
    init sh -c 'rethinkdb restore --connect $RETHINKDB_HOST:$RETHINKDB_PORT --force /rethink-dump.tar.gz'
```

## Initialization

The default entrypoint to the init container generates a User, Authority, and Application dependent on the environment variables below.

- `email`: `PLACE_EMAIL`, required.
- `username`: `PLACE_USERNAME`, required.
- `password`: `PLACE_PASSWORD`, required.
- `application_name`: `PLACE_APPLICATION` || `"backoffice"`
- `domain`: `PLACE_DOMAIN` || `"localhost:8080"`
- `tls`: `PLACE_TLS == "true"`
- `auth_host`: `PLACE_AUTH_HOST` || `"auth"`
- `development`: `ENV == "development"`
- `backoffice_branch`: `PLACE_BACKOFFICE_BRANCH`, `build/prod` or `build/dev` dependent on environment.
- `backoffice_commmit`: `PLACE_BACKOFFICE_COMMIT` ||`"HEAD"`

## Backup Container

`Dockerfile.rethinkdb-backup` generates a container that will backup the state of RethinkDB to S3.
By default, the backup will take place at midnight every day.

- `cron`: `BACKUP_CRON` || `0 0 * * *`
- `rethinkdb_host`: `RETHINKDB_HOST` || `"localhost"`
- `rethinkdb_port`: `RETHINKDB_PORT` || `28019`
- `rethinkdb_db`: `RETHINKDB_DB`
- `aws_region`: `AWS_REGION`, required.
- `aws_key`: `AWS_KEY`, required,
- `aws_secret`: `AWS_SECRET`, required.
- `aws_s3_bucket`: `AWS_S3_BUCKET`, required.
- `aws_kms_key_id`: `AWS_KMS_KEY_ID`

## Scripts

- `help`: List all defined tasks

- `check:user`: Check for existence of a user
    * `domain`: The PlaceOS domain the user is associated with (e.g. `example.com`). Required.
    * `email`: Email of the user (e.g. `alice@example.com`). Required.

- `create:placeholders`: Creates a representative set of documents in RethinkDB

- `create:authority`: Creates an Authority
    * `domain`: Defaults to `PLACE_DOMAIN` || `"localhost:8080"`
    * `tls`: Defaults to `PLACE_TLS` || `false`

- `create:application`: Creates an Application
    * `authority`: Authority ID. Required.
    * `base`: Defaults to `"http://localhost:8080"`
    * `name`: Defaults to `"backoffice"`
    * `redirect_uri`: Defaults to `"#{base}/#{name}/oauth-resp.html"`
    * `scope`: Defaults to `"public"`

- `create:user`: Creates a User
    * `authority_id`: Id of Authority. Required.
    * `email`: Email of user. Required.
    * `username`: Username of user. Required.
    * `password`: Password of user. Required.
    * `sys_admin`: Defaults to `false`
    * `support`: Defaults to `false`

- `backup:rethinkdb`: Backup RethinkDB to S3.
    * `rethinkdb_host`: Defaults to `RETHINKDB_HOST` || `"localhost"`
    * `rethinkdb_port`: Defaults to `RETHINKDB_PORT` || `28019`
    * `rethinkdb_db`: Defaults to `RETHINKDB_DB`, or the entire database
    * `aws_s3_bucket`: Defaults to `AWS_S3_BUCKET`, required.
    * `aws_region`: Defaults to `AWS_REGION`, required.
    * `aws_key`: Defaults to `AWS_KEY`, required,
    * `aws_secret`: Defaults to `AWS_SECRET`, required.
    * `aws_kms_key_id`: Defaults to `AWS_KMS_KEY_ID`

- `secret:rotate_server_secret`: Rotate from old server secret to current value in `PLACE_SERVER_SECRET`
    * `old_secret`: The previous value of `PLACE_SERVER_SECRET`, required.

- `restore:rethinkdb`: Restore RethinkDB from S3.
    * `rethinkdb_host`: Defaults to `RETHINKDB_HOST` || `"localhost"`
    * `rethinkdb_port`: Defaults to `RETHINKDB_PORT` || `28019`
    * `force_restore`: Defaults to `RETHINKDB_FORCE_RESTORE` || `false`
    * `aws_s3_object`: Object to restore DB from. Defaults to `AWS_S3_BUCKET`, required.
    * `aws_s3_bucket`: Defaults to `AWS_S3_BUCKET`, required.
    * `aws_region`: Defaults to `AWS_REGION`, required.
    * `aws_key`: Defaults to `AWS_KEY`, required,
    * `aws_secret`: Defaults to `AWS_SECRET`, required.
    * `aws_kms_key_id`: Defaults to `AWS_KMS_KEY_ID`

- `drop`: Drops Elasticsearch and RethinkDB
    * Runs `drop:elastic` and `drop:db` via environmental configuration

- `drop:elastic`: Deletes all elastic indices tables
    * `host`: Defaults to `ES_HOST` || `"localhost"`
    * `port`: Defaults to `ES_PORT` || `9200`

- `drop:db`: Drops all RethinkDB tables
    * `host`: Defaults to `RETHINKDB_HOST` || `"localhost"`
    * `port`: Defaults to `RETHINKDB_PORT` || `28015`
    * `user`: Defaults to `RETHINKDB_USER` || `"admin"`
    * `password`: Defaults to `RETHINKDB_PASS` || `""`

## Development

- Create a function in a relevant file under `src/tasks`
- Write the task binding in `src/sam.cr`
- Document it

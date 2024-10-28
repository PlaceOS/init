# PlaceOS Init Container

[![Build](https://github.com/PlaceOS/init/actions/workflows/build.yml/badge.svg)](https://github.com/PlaceOS/init/actions/workflows/build.yml)
[![CI](https://github.com/PlaceOS/init/actions/workflows/ci.yml/badge.svg)](https://github.com/PlaceOS/init/actions/workflows/ci.yml)
[![Changelog](https://img.shields.io/badge/Changelog-available-github.svg)](/CHANGELOG.md)

A set of scripts for initialization of PlaceOS.

## Usage

The scripts are methods wrapped by a [sam.cr](https://github.com/imdrasil/sam.cr) interface. Most use named arguments which are used as [described here](https://github.com/imdrasil/sam.cr#tasks-with-arguments).

Execute scripts as one-off container jobs.

## Example

```bash
# Initialize PostgreSQL database
docker-compose run --no-deps -it init task db:init host=$PG_HOST port=$PG_PORT db=$PG_DB user=$PG_USER password=$PG_PASSWORD
```

```bash
# Dump PostgreSQL database to local filesystem
docker-compose run --no-deps -it init task db:dump host=$PG_HOST port=$PG_PORT db=$PG_DB user=$PG_USER password=$PG_PASSWORD
```

```bash
# Restore PostgreSQL database from local filesystem dump
docker-compose run --no-deps -it init task db:restore path=DUMP_FILE_LOCATION host=$PG_HOST port=$PG_PORT db=$PG_DB user=$PG_USER password=$PG_PASSWORD
```

```bash
# Migrate RethinkDB dump to PostgreSQL database
docker-compose run --no-deps -it init task migrate:rethink_dump path=DUMP_FILE_LOCATION host=$PG_HOST port=$PG_PORT db=$PG_DB user=$PG_USER password=$PG_PASSWORD clean_before=true
```

```bash
# Create a set of placeholder records
docker-compose run --no-deps -it init task create:placeholder
```

```bash
# Create an Authority
docker-compose run --no-deps -it init task create:authority domain="localhost:8080"
```

```bash
# Create a backoffice application hosted on `http://localhost:4200`
docker-compose run --no-deps -it init task create:application \
    authority_id=<authority_id> \
    name="development" \
    base="http://localhost:4200" \
    redirect_uri="http://localhost:4200/backoffice/oauth-resp.html"
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
docker-compose run --no-deps -it init task restore:pg \
    pg_host=$PG_HOST \
    pg_port=$PG_PORT \
    pg_db=$PG_DB \
    pg_user=$PG_USER \
    pg_password=$PG_PASS \
    force_restore=$PG_FORCE_RESTORE \
    aws_region=$AWS_REGION \
    aws_s3_bucket=$AWS_S3_BUCKET \
    aws_s3_object=$AWS_S3_BUCKET \
    aws_key=$AWS_KEY \
    aws_secret=$AWS_SECRET
```

```bash
# Restore to a database backup from filesystem
docker-compose run --no-deps \
    -v /etc/placeos/pg_dump_2020-07-14T14_26_19.gz:/pg-dump.gz:Z \
    init task db:restore user=$PG_USER  password=$PG_PASS db=$PG_DB path=/pg-dump.gz
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

`Dockerfile.pg-backup` generates a container that will backup the state of PG to `S3` or `Azure Storage` depending on the environment variables.
By default, the backup will take place at midnight every day.

#### Common

- `cron`: `BACKUP_CRON` || `0 0 * * *`
- `pg_host`: `PG_HOST` || `"localhost"`
- `pg_port`: `PG_PORT` || `5432`
- `pg_db`: `PG_DB`, required.
- `pg_user`: `PG_USER`, required.
- `pg_password`: `PG_PASS`, required.
- `postfix`: `PG_DUMP_POSTFIX`

#### S3

- `aws_region`: `AWS_REGION`, required.
- `aws_key`: `AWS_KEY`, required,
- `aws_secret`: `AWS_SECRET`, required.
- `aws_s3_bucket`: `AWS_S3_BUCKET`, required.
- `aws_kms_key_id`: `AWS_KMS_KEY_ID`

#### Azure Storage

- `az_account`: `AZURE_STORAGE_ACCOUNT_NAME`. Use either combination of `az_account/az_key` **OR** `az_connstr`
- `az_key`: `AZURE_STORAGE_ACCOUNT_KEY`
- `az_connstr`: `AZURE_STORAGE_CONNECTION_STRING`
- `az_container`: `AZURE_STORAGE_CONTAINER`, required.

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

- `backup:pg`: Backup PostgreSQL DB to S3.
    * `pg_host`: Defaults to `PG_HOST` || `"localhost"`
    * `pg_port`: Defaults to `PG_PORT` || `5432`
    * `pg_db`: Defaults to `PG_DB`, or the postgres database
    * `pg_user`: Defaulto `PG_USER`, or postgres
    * `pg_password`: Defaults to `PG_PASS`
    * `postfix`: Defaults to `PG_DUMP_POSTFIX`
    * `aws_s3_bucket`: Defaults to `AWS_S3_BUCKET`, required.
    * `aws_region`: Defaults to `AWS_REGION`, required.
    * `aws_key`: Defaults to `AWS_KEY`, required,
    * `aws_secret`: Defaults to `AWS_SECRET`, required.
    * `aws_kms_key_id`: Defaults to `AWS_KMS_KEY_ID`

- `backup:az`: Backup PostgreSQL DB to Azure Storage.
    * `pg_host`: Defaults to `PG_HOST` || `"localhost"`
    * `pg_port`: Defaults to `PG_PORT` || `5432`
    * `pg_db`: Defaults to `PG_DB`, or the postgres database
    * `pg_user`: Defaulto `PG_USER`, or postgres
    * `pg_password`: Defaults to `PG_PASS`
    * `postfix`: Defaults to `PG_DUMP_POSTFIX`
    * `az_account`: Defaults to `AZURE_STORAGE_ACCOUNT_NAME`. Use either combination of `az_account/az_key` OR `az_connstr`
    * `az_key`: Defaults to `AZURE_STORAGE_ACCOUNT_KEY`.
    * `az_connstr`: Defaults to `AZURE_STORAGE_CONNECTION_STRING`,
    * `az_container`: Defaults to `AZURE_STORAGE_CONTAINER`, required.

- `secret:rotate_server_secret`: Rotate from old server secret to current value in `PLACE_SERVER_SECRET`
    * `old_secret`: The previous value of `PLACE_SERVER_SECRET`, required.

- `restore:pg`: Restore PostgreSQL DB from S3.
    * `pg_host`: Defaults to `PG_HOST` || `"localhost"`
    * `pg_port`: Defaults to `PG_PORT` || `5432`
    * `pg_db`: Defaults to `PG_DB`, or the postgres database
    * `pg_user`: Defaulto `PG_USER`, or postgres
    * `pg_password`: Defaults to `PG_PASS`
    * `force_restore`: Defaults to `PG_FORCE_RESTORE` || `false`
    * `aws_s3_object`: Object to restore DB from. Defaults to `AWS_S3_BUCKET`, required.
    * `aws_s3_bucket`: Defaults to `AWS_S3_BUCKET`, required.
    * `aws_region`: Defaults to `AWS_REGION`, required.
    * `aws_key`: Defaults to `AWS_KEY`, required,
    * `aws_secret`: Defaults to `AWS_SECRET`, required.
    * `aws_kms_key_id`: Defaults to `AWS_KMS_KEY_ID`

- `restore:az`: Restore PostgreSQL DB from Azure Storage Blob.
    * `pg_host`: Defaults to `PG_HOST` || `"localhost"`
    * `pg_port`: Defaults to `PG_PORT` || `5432`
    * `pg_db`: Defaults to `PG_DB`, or the postgres database
    * `pg_user`: Defaulto `PG_USER`, or postgres
    * `pg_password`: Defaults to `PG_PASS`
    * `force_restore`: Defaults to `PG_FORCE_RESTORE` || `false`
    * `az_account`: Defaults to `AZURE_STORAGE_ACCOUNT_NAME`. Use either combination of `az_account/az_key` OR `az_connstr`
    * `az_key`: Defaults to `AZURE_STORAGE_ACCOUNT_KEY`.
    * `az_connstr`: Defaults to `AZURE_STORAGE_CONNECTION_STRING`,
    * `az_container`: Defaults to `AZURE_STORAGE_CONTAINER`, required.
    * `az_blob_object`: Object to restore DB from. Defaults to `AZURE_STORAGE_BLOB_OBJECT`, required.

- `drop`: Drops Elasticsearch and PostgreSQL DB
    * Runs `drop:elastic` and `drop:db` via environmental configuration

- `drop:elastic`: Deletes all elastic indices tables
    * `host`: Defaults to `ES_HOST` || `"localhost"`
    * `port`: Defaults to `ES_PORT` || `9200`

- `drop:db`: Drops all PostgreSQL DB tables
    * `db`: Defaults `PG_DB` || `"postgres"`
    * `host`: Defaults to `PG_HOST` || `"localhost"`
    * `port`: Defaults to `PG_PORT` || `5432`
    * `user`: Defaults to `PG_USER` || `"postgres"`
    * `password`: Defaults to `PG_PASS` || `""`

- `db:clean`: Clean PostgreSQL Database by deleting old records.
    * `db`: Defaults `PG_DB` || `"postgres"`
    * `host`: Defaults to `PG_HOST` || `"localhost"`
    * `port`: Defaults to `PG_PORT` || `5432`
    * `user`: Defaults to `PG_USER` || `"postgres"`
    * `password`: Defaults to `PG_PASS` || `""`
    * `interval`: Data interval, required

> For `interval` syntax refer to [Postgresql Interval datatype](https://www.postgresql.org/docs/current/datatype-datetime.html#DATATYPE-INTERVAL-INPUT)
```

## Development

- Create a function in a relevant file under `src/tasks`
- Write the task binding in `src/sam.cr`
- Document it

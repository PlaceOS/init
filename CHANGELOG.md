## v0.20.8 (2023-05-23)

### Fix

- **migrate_data**: don't migrate asset data

## v0.20.7 (2023-05-10)

### Fix

- **db/migrations**: make models repo the source of truth

## v0.20.6 (2023-03-15)

### Refactor

- migrate to postgres ([#80](https://github.com/PlaceOS/init/pull/80))

## v0.20.5 (2023-03-06)

### Fix

- **dockerfile**: Add tzdata for timezone in final image ([#84](https://github.com/PlaceOS/init/pull/84))

## v0.20.4 (2023-03-01)

### Fix

- **entities**: adds building, level parent property. Fixes [#82](https://github.com/PlaceOS/init/pull/82) ([#83](https://github.com/PlaceOS/init/pull/83))

## v0.20.3 (2023-01-30)

### Fix

- **Dockerfile**: python compatibility for rethinkdb backups ([#81](https://github.com/PlaceOS/init/pull/81))

## v0.20.2 (2022-09-14)

### Fix

- **grant**: remove doorkeeper grants without a ttl ([#74](https://github.com/PlaceOS/init/pull/74))

## v0.20.1 (2022-09-08)

### Fix

- **Dockerfile**: don't use edge libraries ([#73](https://github.com/PlaceOS/init/pull/73))

## v0.20.0 (2022-09-07)

### Feat

- add support for ARM64 platform ([#72](https://github.com/PlaceOS/init/pull/72))

## v0.19.0 (2022-09-02)

### Feat

- remove libsodium requirement ([#71](https://github.com/PlaceOS/init/pull/71))
- **initialization**: use `PLACE_SKIP_PLACEHOLDERS` to skip base entities ([#67](https://github.com/PlaceOS/init/pull/67))

### Fix

- **entities**: upsert appliation on name and redirect_uri ([#66](https://github.com/PlaceOS/init/pull/66))

## v0.18.2 (2022-05-03)

### Fix

- update `placeos-log-backend`

## v0.18.1 (2022-04-28)

### Fix

- **telemetry**: seperate telemetry file

## v0.18.0 (2022-04-27)

### Feat

- **logging**: configure OpenTelemetry

## v0.17.3 (2022-04-21)

### Fix

- **migration/user-id-prefix**: raw reql to delete old user

## v0.17.2 (2022-04-21)

### Fix

- **migrations**: lock migration task

## v0.17.1 (2022-04-20)

### Fix

- **migration/user-id-prefix**: skip ORM when creating new user

## v0.17.0 (2022-04-20)

### Feat

- **tasks:start**: synchronize the start job

## v0.16.3 (2022-04-20)

### Fix

- **migration/user-id-prefix**: flag model as new

## v0.16.2 (2022-04-20)

### Fix

- **migrations/user-id-prefix**: solves issue with changing primary key ([#63](https://github.com/PlaceOS/init/pull/63))

## v0.16.1 (2022-04-19)

### Fix

- **migrations/1.2204-001-user_id_prefix**: don't use local validation to migrate id ([#62](https://github.com/PlaceOS/init/pull/62))

## v0.16.0 (2022-04-13)

### Feat

- **migration**: ensure user id prefixed by user table name ([#61](https://github.com/PlaceOS/init/pull/61))

## v0.15.3 (2022-04-08)

### Fix

- **migration**: patch to allow for coerced value

## v0.15.2 (2022-04-08)

### Refactor

- **metadata**: migrate Metadata.details to JSON ([#59](https://github.com/PlaceOS/init/pull/59))

## v0.15.1 (2022-03-17)

### Fix

- **generate-secrets**: discards extra lines(logging) in `create:instance_key` ([#57](https://github.com/PlaceOS/init/pull/57))

## v0.15.0 (2022-03-03)

### Feat

- **chronograf**: Generate secrets for Chronograf running in a docker-compose environment ([#47](https://github.com/PlaceOS/init/pull/47))
- **scripts/generate-secrets**: server secret
- **task**: secret:rotate_server_secret ([#49](https://github.com/PlaceOS/init/pull/49))
- instance telemetry key ([#48](https://github.com/PlaceOS/init/pull/48))
- **initialization**: support pinning interface
- **tasks**: add a check for user existence ([#39](https://github.com/PlaceOS/init/pull/39))
- migration for backoffice branch rename
- **logging**: configure `Log.progname`
- **entities**: add zones with a tag for each level of the zone hierarchy
- **kibana**: set up Metrics tab showing Kibana in authority config
- **secrets**: generate kibana htpasswd
- support ordering for migrations
- settings parent type migration
- base migration framework
- **logstash**: add placeos-log-backend
- add restore entrypoint

### Fix

- **tasks/entities**: remove `Edge` placeholder
- **scripts/generate-secrets**: accept password via input
- **logging**: prevent log output for LOG_LEVEL=NONE
- **scripts/generate-secrets**: malformed bash conditional
- allow spaces in password ([#51](https://github.com/PlaceOS/init/pull/51))
- **scripts/generate-secrets**: fix typo
- unify instance secrets ([#50](https://github.com/PlaceOS/init/pull/50))
- ensure no logs on secret generation
- **scripts/generate-secrets**: bug in creating constant
- **scripts/generate-secrets**: use path to locate `task`
- backoffice branch names
- compilation error on migrations sort
- branch names on backoffice creation
- **secrets**: typo in kibana htpasswd check
- double serialization of parent type
- **constants**: space in env var
- **task:restore**: remove KMS

### Refactor

- central build ci ([#54](https://github.com/PlaceOS/init/pull/54))
- **user**: use new Email struct
- **initialization**: change default backoffice branch to build/(dev/prod)
- **entities**: cleaner name for dummy entities

## v0.9.0 (2021-01-15)

### Feat

- **entities**: add edge model to placeholder documents
- add secrets generation script
- support forced restore from backup
- restore
- rethinkdb backup

### Fix

- dev builds
- **secret-gen**: update base64 [coreutils]
- use epoch timestamp for rethinkdb dump file name

### Refactor

- **entities**: dry out document creation methods
- pull constants out to a constants.cr

## v0.7.1 (2020-07-17)

### Feat

- **rethinkdb**: install rethinkdb and python driver

### Fix

- **entities**: set branch on repo entitity

### Refactor

- use branches for backoffice interfaces

## v0.6.0 (2020-07-02)

## v0.5.4 (2020-06-29)

## v0.5.3 (2020-06-24)

## v0.5.2 (2020-06-19)

### Feat

- **start**: create backoffice interface repository
- **entitites:application**: support specifying `redirect_uri`

### Fix

- use latest private drivers for placeholders
- use ::Log.setup
- missed owner_id on app registrations

### Refactor

- rename shard `placeos-init`, use `placeos-models`

## v0.3.4 (2020-05-14)

### Fix

- **entities**: use latest private_helper commit
- **create:application**: incorrect parameter order

## v0.3.3 (2020-05-12)

### Fix

- **entities**: correct `redirect_uri`

## v0.3.2 (2020-05-12)

### Fix

- **initialization**: correct values in Authority creation
- **entities**: create an `n` byte hexstring for secure string

## v0.3.1 (2020-05-11)

### Fix

- **entities**: set `_new_flag` on Application

## v0.3.0 (2020-05-07)

### Refactor

- use `ENV` instead of `SG_ENV`

## v0.2.0 (2020-05-07)

### Feat

- **tasks**: cleanup of src/tasks
- init init

### Fix

- **shard.yml**: correct `target` to `targets` and add `executables` declaration

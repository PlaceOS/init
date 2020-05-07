# PlaceOS Init Container

A set of scripts for initialization of PlaceOS.

## Usage

The scripts are methods wrapped by a [sam.cr](https://github.com/imdrasil/sam.cr) interface. Most use named arguments which are used as [described here](https://github.com/imdrasil/sam.cr#tasks-with-arguments).

Execute scripts as one-off container jobs.

## Example

```bash
# Create a set of placeholder documents
docker run -it placeos/init -- make sam create:placeholder
```

```bash
# Create an Authority
docker run -it placeos/init -- make sam create:authority domain="localhost:8080"
```

```bash
# Create a User
docker run -it placeos/init -- make sam create:user \
                                        authority_id="s0mek1nd4UUID" \
                                        email="support@place.tech" \
                                        username="burger" \
                                        password="burgerR00lz" \
                                        sys_admin=true \
                                        support=true
```

## Container Entrypoint

The default entrypoint to the container generates a User, Authority, and Application dependent on the environment variables below.

- `email`: `PLACE_EMAIL`, required.
- `username`: `PLACE_USERNAME`, required.
- `password`: `PLACE_PASSWORD`, required.
- `application_name`: `PLACE_APPLICATION` || `"backoffice"`
- `domain`: `PLACE_DOMAIN` || `"localhost:8080"`
- `tls`: `PLACE_TLS == "true"`
- `auth_host`: `PLACE_AUTH_HOST` || `"auth"`
- `development`: `ENV == "development"`

## Scripts

- `create:placeholders`: Creates a representative set of documents in RethinkDB

- `create:authority`: Creates an Authority
    * `domain`: Defaults to `PLACE_DOMAIN` || `"localhost:8080"`
    * `tls`: Defaults to `PLACE_TLS` || `false`

- `create:application`: Creates an Application
    * `base`: Defaults to `"http://localhost:8080"`
    * `name`: Defaults to `"backoffice"`

- `create:user`: Creates a User
    * `authority_id`: Id of Authority. Required.
    * `email`: Email of user. Required.
    * `username`: Username of user. Required.
    * `password`: Password of user. Required.
    * `sys_admin`: Defaults to `false`
    * `support`: Defaults to `false`

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
- Write the sam binding in `src/sam.cr`
- Document it

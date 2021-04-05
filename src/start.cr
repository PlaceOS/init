require "./tasks"
require "./migrations"

module PlaceOS
  Migrations.apply_all

  Tasks::Initialization.start(
    application_name: APPLICATION_NAME,
    domain: DOMAIN,
    tls: TLS,
    email: EMAIL,
    username: USERNAME,
    password: PASSWORD,
    auth_host: AUTH_HOST,
  )
end

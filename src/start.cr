require "./tasks"

module PlaceOS
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

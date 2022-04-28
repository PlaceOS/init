require "./tasks"
require "./migrations"
require "./logging"

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
    metrics_route: METRICS_ROUTE,
    backoffice_branch: BACKOFFICE_BRANCH,
    backoffice_commit: BACKOFFICE_COMMIT,
    analytics_route: ANALYTICS_ROUTE,
  )
end

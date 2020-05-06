require "./tasks"

module PlaceOS
  Tasks::Initialization.start(
    application_name: ENV["PLACE_APPLICATION"]? || "backoffice",
    domain: ENV["PLACE_DOMAIN"]? || "localhost:8080",
    tls: (ENV["PLACE_TLS"]?.try(&.downcase)) == "true",
    email: ENV["PLACE_EMAIL"]? || abort("missing PLACE_EMAIL"),
    username: ENV["PLACE_USERNAME"]? || abort("missing PLACE_USERNAME"),
    password: ENV["PLACE_PASSWORD"]? || abort("missing PLACE_PASSWORD"),
    auth_host: ENV["PLACE_AUTH_HOST"]? || "auth",
    development: ENV["SG_ENV"]? == "development",
  )
end

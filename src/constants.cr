module PlaceOS
  PROD = (ENV["ENV"]? || ENV["SG_ENV"]?) == "production"

  # Backup constants
  BACKUP_CRON = ENV["PLACE_BACKUP_CRON"]? || "0 0 * * *"

  # Initialization constants
  APPLICATION_NAME = ENV["PLACE_APPLICATION"]? || "backoffice"
  DOMAIN           = ENV["PLACE_DOMAIN"]? || "localhost:8080"
  TLS              = ENV["PLACE_TLS"]?.try(&.downcase) == "true"
  EMAIL            = ENV["PLACE_EMAIL"]? || abort("missing PLACE_EMAIL")
  USERNAME         = ENV["PLACE_USERNAME"]? || abort("missing PLACE_USERNAME")
  PASSWORD         = ENV["PLACE_PASSWORD"]? || abort("missing PLACE_PASSWORD")
  AUTH_HOST        = ENV["PLACE_AUTH_HOST"]? || "auth"
end

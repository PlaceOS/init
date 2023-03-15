module PlaceOS
  APP_NAME = "init"
  VERSION  = {{ `shards version "#{__DIR__}"`.chomp.stringify.downcase }}

  PROD = (ENV["ENV"]? || ENV["SG_ENV"]?) == "production"

  # Backup/Restore constants

  BACKUP_CRON    = ENV["PLACE_BACKUP_CRON"]? || "0 0 * * *"
  AWS_REGION     = ENV["AWS_REGION"]?
  AWS_KEY        = ENV["AWS_KEY"]?
  AWS_SECRET     = ENV["AWS_SECRET"]?
  AWS_S3_OBJECT  = ENV["AWS_S3_OBJECT"]?
  AWS_S3_BUCKET  = ENV["AWS_S3_BUCKET"]?
  AWS_KMS_KEY_ID = ENV["AWS_KMS_KEY_ID"]?

  PG_FORCE_RESTORE = self.boolean_env("PG_FORCE_RESTORE")

  # Initialization constants

  APPLICATION_NAME = ENV["PLACE_APPLICATION"]? || "backoffice"
  DOMAIN           = ENV["PLACE_DOMAIN"]? || "localhost:8080"
  TLS              = self.boolean_env("PLACE_TLS")
  EMAIL            = ENV["PLACE_EMAIL"]? || abort("missing PLACE_EMAIL")
  USERNAME         = ENV["PLACE_USERNAME"]? || abort("missing PLACE_USERNAME")
  PASSWORD         = ENV["PLACE_PASSWORD"]? || abort("missing PLACE_PASSWORD")
  AUTH_HOST        = ENV["PLACE_AUTH_HOST"]? || "auth"
  METRICS_ROUTE    = ENV["PLACE_METRICS_ROUTE"]? || "monitor"

  ANALYTICS_ROUTE         = ENV["PLACE_ANALYTICS_ROUTE"]? || "analytics"
  ANALYTICS_CALLBACK_PATH = ENV["ANALYTICS_CALLBACK_PATH"]? || "oauth/PlaceOS/callback"

  SKIP_PLACEHOLDERS = self.boolean_env("PLACE_SKIP_PLACEHOLDERS")

  # Backoffice

  BACKOFFICE_BRANCH = ENV["PLACE_BACKOFFICE_BRANCH"]?.presence || "build/#{production? ? "prod" : "dev"}"
  BACKOFFICE_COMMIT = ENV["PLACE_BACKOFFICE_COMMIT"]?.presence || "HEAD"

  # Resource configurations

  ES_HOST = ENV["ES_HOST"]? || "localhost"
  ES_PORT = ENV["ES_PORT"]?.try &.to_i || 9200

  PG_DB   = ENV["PG_DB"]? || "postgres"
  PG_HOST = ENV["PG_HOST"]? || "localhost"
  PG_PORT = ENV["PG_PORT"]?.try &.to_i || 5432
  PG_USER = ENV["PG_USER"]? || "postgres"
  PG_PASS = ENV["PG_PASS"]? || ENV["PG_PASSWORD"]?

  PG_DATABASE_URL = ENV["PG_DATABASE_URL"]? || "postgresql://#{PG_USER}:#{PG_PASS}@#{PG_HOST}:#{PG_PORT}/#{PG_DB}"

  class_getter? production : Bool = PROD

  protected def self.boolean_env(key) : Bool
    !!ENV[key]?.try(&.downcase.in?("1", "true"))
  end
end

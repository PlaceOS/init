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

  RETHINKDB_FORCE_RESTORE = self.boolean_env("RETHINKDB_FORCE_RESTORE")

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

  RETHINKDB_DB   = ENV["RETHINKDB_DB"]?
  RETHINKDB_HOST = ENV["RETHINKDB_HOST"]? || "localhost"
  RETHINKDB_PORT = ENV["RETHINKDB_PORT"]?.try &.to_i || 28015
  RETHINKDB_USER = ENV["RETHINKDB_USER"]?
  RETHINKDB_PASS = ENV["RETHINKDB_PASS"]?

  class_getter? production : Bool = PROD

  protected def self.boolean_env(key) : Bool
    !!ENV[key]?.try(&.downcase.in?("1", "true"))
  end
end

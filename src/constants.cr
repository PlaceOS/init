module PlaceOS
  PROD = (ENV["ENV"]? || ENV["SG_ENV"]?) == "production"

  # Backup/Restore constants

  BACKUP_CRON    = ENV["PLACE_BACKUP_CRON"]? || "0 0 * * *"
  AWS_REGION     = ENV["AWS_REGION"]?
  AWS_KEY        = ENV["AWS_KEY"]?
  AWS_SECRET     = ENV["AWS_SECRET"]?
  AWS_S3_OBJECT  = ENV["AWS_S3_OBJECT"]?
  AWS_S3_BUCKET  = ENV["AWS_S3_BUCKET"]?
  AWS_KMS_KEY_ID = ENV["AWS_KMS_KEY_ID"]?

  RETHINKDB_FORCE_RESTORE = ENV["RETHINKDB_FORCE_RESTORE"]?.try(&.downcase) == "true"

  # Initialization constants

  APPLICATION_NAME = ENV["PLACE_APPLICATION"]? || "backoffice"
  DOMAIN           = ENV["PLACE_DOMAIN"]? || "localhost:8080"
  TLS              = ENV["PLACE_TLS"]?.try(&.downcase) == "true"
  EMAIL            = ENV["PLACE_EMAIL"]? || abort("missing PLACE_EMAIL")
  USERNAME         = ENV["PLACE_USERNAME"]? || abort("missing PLACE_USERNAME")
  PASSWORD         = ENV["PLACE_PASSWORD"]? || abort("missing PLACE_PASSWORD")
  AUTH_HOST        = ENV["PLACE_AUTH_HOST"]? || "auth"
  KIBANA_ROUTE     = ENV["KIBANA_ROUTE"]? || "monitor"

  # Resource configurations

  ES_HOST = ENV["ES_HOST"]? || "localhost"
  ES_PORT = ENV["ES_PORT"]?.try &.to_i || 9200

  RETHINKDB_DB   = ENV["RETHINKDB_DB"]?
  RETHINKDB_HOST = ENV["RETHINKDB_HOST"]? || "localhost"
  RETHINKDB_PORT = ENV["RETHINKDB_PORT"]?.try &.to_i || 28015
  RETHINKDB_USER = ENV["RETHINKDB_USER"]?
  RETHINKDB_PASS = ENV["RETHINKDB_PASS"]?
end

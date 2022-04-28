require "./tasks"
require "./logging"

module PlaceOS
  Tasks::Backup.rethinkdb_backup_cron(
    cron: BACKUP_CRON,
    rethinkdb_host: RETHINKDB_HOST,
    rethinkdb_port: RETHINKDB_PORT,
    rethinkdb_db: RETHINKDB_DB,
    rethinkdb_password: RETHINKDB_PASS,
    aws_region: AWS_REGION || abort("AWS_REGION is unset"),
    aws_key: AWS_KEY || abort("AWS_KEY is unset"),
    aws_secret: AWS_SECRET || abort("AWS_SECRET is unset"),
    aws_s3_bucket: AWS_S3_BUCKET || abort("AWS_S3_BUCKET is unset"),
    aws_kms_key_id: AWS_KMS_KEY_ID,
  )
end

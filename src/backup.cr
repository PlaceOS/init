require "./tasks"
require "./logging"

module PlaceOS
  if (AZURE_STORAGE_ACCOUNT_NAME && AZURE_STORAGE_ACCOUNT_KEY) || AZURE_STORAGE_CONNECTION_STRING
    Tasks::Backup.az_backup_cron(
      cron: BACKUP_CRON,
      pg_host: PG_HOST,
      pg_port: PG_PORT,
      pg_db: PG_DB,
      pg_user: PG_USER,
      pg_password: PG_PASS,
      az_account: AZURE_STORAGE_ACCOUNT_NAME,
      az_key: AZURE_STORAGE_ACCOUNT_KEY,
      az_connstr: AZURE_STORAGE_CONNECTION_STRING,
      az_container: AZURE_STORAGE_CONTAINER || abort("AZURE_STORAGE_CONTAINER is unset")
    )
  else
    Tasks::Backup.pg_backup_cron(
      cron: BACKUP_CRON,
      pg_host: PG_HOST,
      pg_port: PG_PORT,
      pg_db: PG_DB,
      pg_user: PG_USER,
      pg_password: PG_PASS,
      aws_region: AWS_REGION || abort("AWS_REGION is unset"),
      aws_key: AWS_KEY || abort("AWS_KEY is unset"),
      aws_secret: AWS_SECRET || abort("AWS_SECRET is unset"),
      aws_s3_bucket: AWS_S3_BUCKET || abort("AWS_S3_BUCKET is unset"),
      aws_kms_key_id: AWS_KMS_KEY_ID,
    )
  end
end

require "./tasks"
require "./logging"

module PlaceOS
  if (AZURE_STORAGE_ACCOUNT_NAME && AZURE_STORAGE_ACCOUNT_KEY) || AZURE_STORAGE_CONNECTION_STRING
    Tasks::Restore.az_restore(
      pg_host: PG_HOST,
      pg_port: PG_PORT,
      pg_db: PG_DB,
      pg_user: PG_USER,
      pg_password: PG_PASS,
      az_account: AZURE_STORAGE_ACCOUNT_NAME,
      az_key: AZURE_STORAGE_ACCOUNT_KEY,
      az_connstr: AZURE_STORAGE_CONNECTION_STRING,
      az_container: AZURE_STORAGE_CONTAINER || abort("AZURE_STORAGE_CONTAINER is unset"),
      az_blob_object: AZURE_STORAGE_BLOB_OBJECT || abort("AZURE_STORAGE_BLOB_OBJECT unset")
    )
  else
    Tasks::Restore.pg_restore(
      pg_host: PG_HOST,
      pg_port: PG_PORT,
      pg_db: PG_DB,
      pg_user: PG_USER,
      pg_password: PG_PASS,
      force_restore: PG_FORCE_RESTORE,
      aws_s3_object: AWS_S3_OBJECT || abort("AWS_S3_OBJECT is unset"),
      aws_region: AWS_REGION || abort("AWS_REGION is unset"),
      aws_key: AWS_KEY || abort("AWS_KEY is unset"),
      aws_secret: AWS_SECRET || abort("AWS_SECRET is unset"),
      aws_s3_bucket: AWS_S3_BUCKET || abort("AWS_S3_BUCKET is unset"),
      aws_kms_key_id: AWS_KMS_KEY_ID,
    )
  end
end

require "../logging"

require "exec_from"
require "tasker"
require "azblob"

require "../utils/postgres"
require "../utils/s3"

module PlaceOS::Tasks::Backup
  extend self
  Log = ::Log.for(self)

  # Backup PostgreSQL database to s3
  #
  def pg_backup(
    pg_host : String,
    pg_port : Int32,
    aws_region : String,
    aws_key : String,
    aws_secret : String,
    aws_s3_bucket : String,
    aws_kms_key_id : String? = nil,
    pg_db : String? = nil,
    pg_user : String? = nil,
    pg_password : String? = nil,
    postfix : String = ""
  )
    Log.context.set(
      pg_host: pg_host,
      pg_port: pg_port,
      pg_db: pg_db || "Full backup",
      aws_s3_bucket: aws_s3_bucket,
      aws_region: aws_region,
    )

    writer = PlaceOS::Utils::S3.new(
      region: aws_region,
      key: aws_key,
      secret: aws_secret,
      bucket: aws_s3_bucket,
      kms_key_id: aws_kms_key_id,
    )

    Log.info { "running postgresql backup" }
    path = PlaceOS::Utils::PostgresDB.dump(
      host: pg_host,
      port: pg_port,
      db: pg_db.not_nil!,
      user: pg_user.not_nil!,
      password: pg_password.not_nil!,
      postfix: postfix
    )

    if path
      writer.write_file(path)
    else
      Log.error { "failed to capture postgresql backup" }
    end
  end

  # Backup PostgreSQL database to Azure Storage
  #
  def az_backup(
    pg_host : String,
    pg_port : Int32,
    az_account : String?,
    az_key : String?,
    az_connstr : String?,
    az_container : String,
    pg_db : String? = nil,
    pg_user : String? = nil,
    pg_password : String? = nil,
    postfix : String = ""
  )
    Log.context.set(
      pg_host: pg_host,
      pg_port: pg_port,
      pg_db: pg_db || "Full backup",
      az_container: az_container
    )

    abort "Neither arguments were given nor AZURE_STORAGE_XXXX environment variables were set" unless (az_account && az_key) || az_connstr
    client = if str = az_connstr
               AZBlob.client(str)
             else
               AZBlob::Client.new(AZBlob::Client::Config.with_shared_key(az_account.not_nil!, az_key.not_nil!))
             end

    Log.info { "running postgresql backup" }
    path = PlaceOS::Utils::PostgresDB.dump(
      host: pg_host,
      port: pg_port,
      db: pg_db.not_nil!,
      user: pg_user.not_nil!,
      password: pg_password.not_nil!,
      postfix: postfix
    )

    if path
      File.open(path) do |file|
        client.put_blob(az_container, path.basename, file)
      end
    else
      Log.error { "failed to capture postgresql backup" }
    end
  end

  # Periodically backup postgres to s3
  #
  def pg_backup_cron(
    pg_host : String,
    pg_port : Int32,
    aws_region : String,
    aws_key : String,
    aws_secret : String,
    aws_s3_bucket : String,
    aws_kms_key_id : String? = nil,
    pg_db : String? = nil,
    pg_user : String? = nil,
    pg_password : String? = nil,
    cron : String = BACKUP_CRON,
    postfix : String = ""
  )
    Log.context.set(
      pg_host: pg_host,
      pg_port: pg_port,
      pg_db: pg_db,
      cron: cron,
    )

    writer = PlaceOS::Utils::S3.new(
      region: aws_region,
      key: aws_key,
      secret: aws_secret,
      bucket: aws_s3_bucket,
      kms_key_id: aws_kms_key_id,
    )

    Log.info { "starting backup cron" }
    Tasker.cron(cron) do
      Log.info { "running postgres backup" }

      path = PlaceOS::Utils::PostgresDB.dump(
        host: pg_host,
        port: pg_port,
        db: pg_db.not_nil!,
        user: pg_user.not_nil!,
        password: pg_password.not_nil!,
        postfix: postfix
      )
      writer.send_file(path) unless path.nil?
    end

    writer.process!
  end

  # Periodically backup postgres to Azure Storage
  #
  def az_backup_cron(
    pg_host : String,
    pg_port : Int32,
    az_account : String?,
    az_key : String?,
    az_connstr : String?,
    az_container : String,
    pg_db : String? = nil,
    pg_user : String? = nil,
    pg_password : String? = nil,
    cron : String = BACKUP_CRON,
    postfix : String = ""
  )
    Log.context.set(
      pg_host: pg_host,
      pg_port: pg_port,
      pg_db: pg_db,
      cron: cron,
    )

    abort "Neither arguments were given nor AZURE_STORAGE_XXXX environment variables were set" unless (az_account && az_key) || az_connstr
    client = if str = az_connstr
               AZBlob.client(str)
             else
               AZBlob::Client.new(AZBlob::Client::Config.with_shared_key(az_account.not_nil!, az_key.not_nil!))
             end

    Log.info { "starting backup cron - azure" }
    Tasker.cron(cron) do
      Log.info { "running postgres backup" }

      path = PlaceOS::Utils::PostgresDB.dump(
        host: pg_host,
        port: pg_port,
        db: pg_db.not_nil!,
        user: pg_user.not_nil!,
        password: pg_password.not_nil!,
        postfix: postfix
      )
      if path
        File.open(path) do |file|
          client.put_blob(az_container, path.basename, file)
        end
      else
        Log.error { "failed to capture postgresql backup" }
      end
    end
  end
end

require "../logging"

require "exec_from"
require "retriable/core_ext/kernel"
require "tasker"

require "../utils/rethinkdb"
require "../utils/s3"

module PlaceOS::Tasks::Backup
  extend self
  Log = ::Log.for(self)

  # Backup rethinkdb to s3
  #
  def rethinkdb_backup(
    rethinkdb_host : String,
    rethinkdb_port : Int32,
    aws_region : String,
    aws_key : String,
    aws_secret : String,
    aws_s3_bucket : String,
    aws_kms_key_id : String? = nil,
    rethinkdb_db : String? = nil,
    rethinkdb_password : String? = nil
  )
    Log.context.set({
      rethinkdb_host: rethinkdb_host,
      rethinkdb_port: rethinkdb_port,
      rethinkdb_db:   rethinkdb_db || "Full backup",
      aws_s3_bucket:  aws_s3_bucket,
      aws_region:     aws_region,
    })

    writer = PlaceOS::Utils::S3.new(
      region: aws_region,
      key: aws_key,
      secret: aws_secret,
      bucket: aws_s3_bucket,
      kms_key_id: aws_kms_key_id,
    )

    Log.info { "running rethinkdb backup" }
    path = PlaceOS::Utils::RethinkDB.dump(
      host: rethinkdb_host,
      port: rethinkdb_port,
      db: rethinkdb_db,
      password: rethinkdb_password,
    )

    if path
      writer.write_file(path)
    else
      Log.error { "failed to capture rethinkdb backup" }
    end
  end

  # Periodically backup rethinkdb to s3
  #
  def rethinkdb_backup_cron(
    rethinkdb_host : String,
    rethinkdb_port : Int32,
    aws_region : String,
    aws_key : String,
    aws_secret : String,
    aws_s3_bucket : String,
    aws_kms_key_id : String? = nil,
    rethinkdb_db : String? = nil,
    rethinkdb_password : String? = nil,
    cron : String = BACKUP_CRON
  )
    Log.context.set({
      rethinkdb_host: rethinkdb_host,
      rethinkdb_port: rethinkdb_port,
      rethinkdb_db:   rethinkdb_db,
      cron:           cron,
    })

    writer = PlaceOS::Utils::S3.new(
      region: aws_region,
      key: aws_key,
      secret: aws_secret,
      bucket: aws_s3_bucket,
      kms_key_id: aws_kms_key_id,
    )

    Log.info { "starting backup cron" }
    Tasker.cron(cron) do
      Log.info { "running rethinkdb backup" }

      path = PlaceOS::Utils::RethinkDB.dump(
        host: rethinkdb_host,
        port: rethinkdb_port,
        db: rethinkdb_db,
        password: rethinkdb_password,
      )
      writer.send_file(path) unless path.nil?
    end

    writer.process!
  end
end

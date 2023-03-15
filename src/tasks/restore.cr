require "../utils/postgres"
require "../utils/s3"

module PlaceOS::Tasks::Restore
  extend self
  Log = ::Log.for(self)

  def pg_restore(
    pg_host : String,
    pg_port : Int32,
    pg_db : String,
    aws_region : String,
    aws_key : String,
    aws_secret : String,
    aws_s3_bucket : String,
    aws_s3_object : String,
    force_restore : Bool = false,
    pg_user : String? = nil,
    pg_password : String? = nil,
    aws_kms_key_id : String? = nil
  )
    Log.context.set({
      pg_host:       pg_host,
      pg_port:       pg_port,
      pg_db:         pg_db,
      force_restore: force_restore,
      aws_s3_object: aws_s3_object,
      aws_s3_bucket: aws_s3_bucket,
      aws_region:    aws_region,
    })

    s3 = PlaceOS::Utils::S3.new(
      region: aws_region,
      key: aws_key,
      secret: aws_secret,
      bucket: aws_s3_bucket,
      kms_key_id: aws_kms_key_id,
    )

    Log.info { "pulling backup from S3" }
    file = File.tempfile("pgdb-backup.tar.gz") do |temporary_io|
      s3.read_file(aws_s3_object) do |object|
        IO.copy(object.body_io, temporary_io)
      end
    end

    Log.info { "restoring PostgreSQL DB" }
    PlaceOS::Utils::PostgresDB.restore(
      path: Path[file.path],
      host: pg_host,
      port: pg_port,
      db: pg_db,
      user: pg_user.not_nil!,
      password: pg_password.not_nil!,
      force_restore: force_restore,
    ).tap { Log.info { "successfully restored PostgreSQL DB" } }
  end
end

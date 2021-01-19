require "../utils/rethinkdb"
require "../utils/s3"

module PlaceOS::Tasks::Restore
  extend self
  Log = ::Log.for(self)

  def rethinkdb_restore(
    rethinkdb_host : String,
    rethinkdb_port : Int32,
    aws_region : String,
    aws_key : String,
    aws_secret : String,
    aws_s3_bucket : String,
    aws_s3_object : String,
    force_restore : Bool = false,
    rethinkdb_password : String? = nil,
    aws_kms_key_id : String? = nil
  )
    Log.context.set({
      rethinkdb_host: rethinkdb_host,
      rethinkdb_port: rethinkdb_port,
      force_restore:  force_restore,
      aws_s3_object:  aws_s3_object,
      aws_s3_bucket:  aws_s3_bucket,
      aws_region:     aws_region,
    })

    s3 = PlaceOS::Utils::S3.new(
      region: aws_region,
      key: aws_key,
      secret: aws_secret,
      bucket: aws_s3_bucket,
      kms_key_id: aws_kms_key_id,
    )

    Log.info { "pulling backup from S3" }
    file = File.tempfile("rethinkdb-backup.tar.gz") do |temporary_io|
      s3.read_file(aws_s3_object) do |object|
        IO.copy(object.body_io, temporary_io)
      end
    end

    Log.info { "restoring RethinkDB" }
    PlaceOS::Utils::RethinkDB.restore(
      path: Path[file.path],
      host: rethinkdb_host,
      port: rethinkdb_port,
      password: rethinkdb_password,
      force_restore: force_restore,
    ).tap { Log.info { "successfully restored rethinkDB" } }
  end
end

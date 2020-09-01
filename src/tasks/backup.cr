require "awscr-s3"
require "exec_from"
require "tasker"
require "retriable/core_ext/kernel"

require "../log"

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
    rethinkdb_db : String? = nil
  )
    Log.context = {
      rethinkdb_host: rethinkdb_host,
      rethinkdb_port: rethinkdb_port,
      rethinkdb_db:   rethinkdb_db,
      aws_s3_bucket:  aws_s3_bucket,
      aws_region:     aws_region,
    }

    writer = S3Writer.new(
      region: aws_region,
      key: aws_key,
      secret: aws_secret,
      bucket: aws_s3_bucket,
      kms_key_id: aws_kms_key_id,
    )

    Log.info { "running rethinkdb backup" }
    path = dump_rethinkdb(rethinkdb_host, rethinkdb_port, rethinkdb_db)
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
    cron : String = BACKUP_CRON
  )
    writer = S3Writer.new(
      region: aws_region,
      key: aws_key,
      secret: aws_secret,
      bucket: aws_s3_bucket,
      kms_key_id: aws_kms_key_id,
    )

    Tasker.cron(cron) do
      Log.info { {
        message:        "running rethinkdb backup",
        rethinkdb_host: rethinkdb_host,
        rethinkdb_port: rethinkdb_port,
        rethinkdb_db:   rethinkdb_db,
        cron:           cron,
      } }
      path = dump_rethinkdb(rethinkdb_host, rethinkdb_port, rethinkdb_db)
      writer.new_file.send(path) unless path.nil?
    end

    writer.process!
  end

  def dump_rethinkdb(host : String, port : Int32, db : String? = nil) : Path?
    directory = Dir.tempdir

    base_arguments = {"dump", "-c", "#{host}:#{port}"}
    arguments = db.nil? ? base_arguments : base_arguments + {"-e", db}

    # Return the file descriptor
    result = ExecFrom.exec_from(directory, "rethinkdb", arguments)
    output = result[:output].to_s
    exit_code = result[:exit_code]

    last_line = output.lines.last

    if exit_code != 0 || !last_line.starts_with?("Done")
      Log.error { "dump_rethinkdb failed with: #{output}" }
      nil
    else
      _, file_name = last_line.split(':', limit: 2)
      Path[file_name.strip]
    end
  end
end

class S3Writer
  getter files_written : UInt64 = 0
  getter new_file : Channel(Path) = Channel(Path).new(1)

  private getter region, key, secret, bucket
  private getter s3 : Awscr::S3::Client { Awscr::S3::Client.new(region, key, secret) }
  private getter headers : Hash(String, String) = {} of String => String

  def initialize(@region : String, @key : String, @secret : String, @bucket : String, kms_key_id : String? = nil)
    if kms_key_id
      # For accessing external S3 via KMS by specifying a CMK
      headers["x-amz-acl"] = "bucket-owner-full-control"
      headers["x-amz-server-side-encryption"] = "aws:kms"
      headers["x-amz-server-side-encryption-aws-kms-key-id"] = kms_key_id
    end
  end

  def shutdown!
    new_file.close
  end

  def write_file(path)
    File.open(path) do |io|
      begin
        retry times: 10, max_interval: 1.minute do
          puts "writing file #{path.basename}"
          STDOUT.flush
          s3.put_object(bucket, path.basename, io, headers: headers)
          @files_written += 1
        end
      rescue ex
        puts ex.inspect_with_backtrace
        STDOUT.flush
      end
    end
  end

  def process!
    loop do
      path = new_file.receive?
      if path
        write_file(path)
      else
        break
      end
    end
  end
end

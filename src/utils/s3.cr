require "awscr-s3"
require "simple_retry"

class PlaceOS::Utils::S3
  getter files_written : UInt64 = 0
  private getter new_file_channel : Channel(Path) { Channel(Path).new(1) }

  private getter region, key, secret, bucket
  private getter s3 : Awscr::S3::Client { Awscr::S3::Client.new(region, key, secret) }
  private getter headers : Hash(String, String) = {} of String => String

  def initialize(@region : String, @key : String, @secret : String, @bucket : String, kms_key_id : String? = nil)
    # if kms_key_id
    #  # For accessing external S3 via KMS by specifying a CMK
    #  headers["x-amz-acl"] = "bucket-owner-full-control"
    #  headers["x-amz-server-side-encryption"] = "aws:kms"
    #  headers["x-amz-server-side-encryption-aws-kms-key-id"] = kms_key_id
    # end
  end

  def shutdown!
    new_file_channel.close
  end

  def send_file(path : Path)
    new_file_channel.send(path)
  end

  def read_file(object : String, &)
    s3.get_object(bucket, object, headers: headers) do |io|
      yield io
    end
  end

  def write_file(path : Path)
    uploader = Awscr::S3::FileUploader.new(s3)
    File.open(path) do |io|
      begin
        SimpleRetry.try_to(base_interval: 0.seconds, max_attempts: 10, max_interval: 1.minute) do |attempt, error|
          if attempt > 1
            Log.error(exception: error) { "failed to write to S3" }
            io.rewind
          end

          Log.info { "attempting to write #{path.basename} to S3" }
          uploader.upload(bucket, path.basename, io, headers)
          @files_written += 1
        end
      rescue ex
        puts ex.inspect_with_backtrace
      end
    end
  end

  def process!
    loop do
      path = new_file_channel.receive?
      if path
        write_file(path)
      else
        break
      end
    end
  end
end

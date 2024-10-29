require "./constants"

require "sam"
require "./tasks"
require "./logging"
require "./ext/*"
namespace "db" do
  desc "Initialize PostgreSQL Database by running the migration scripts"
  task "init" do |_, args|
    arguments = {
      pg_host:     (args["host"]? || PlaceOS::PG_HOST).to_s,
      pg_port:     (args["port"]? || PlaceOS::PG_PORT).to_i,
      pg_db:       (args["db"]? || PlaceOS::PG_DB).to_s,
      pg_user:     (args["user"]? || PlaceOS::PG_USER).try &.to_s,
      pg_password: (args["password"]? || PlaceOS::PG_PASS).to_s,
    }

    PlaceOS::Tasks.pg_init_database(**arguments)
  end

  desc "Dump PostgreSQL Database to local file system"
  task "dump" do |_, args|
    arguments = {
      host:     (args["host"]? || PlaceOS::PG_HOST).to_s,
      port:     (args["port"]? || PlaceOS::PG_PORT).to_i,
      db:       (args["db"]? || PlaceOS::PG_DB).to_s,
      user:     (args["user"]? || PlaceOS::PG_USER).try &.to_s,
      password: (args["password"]? || PlaceOS::PG_PASS).to_s,
      postfix:  (args["postfix"]? || PlaceOS::PG_DUMP_POSTFIX).to_s,
    }

    ret = PlaceOS::Utils::PostgresDB.dump(**arguments)
    puts "Database dumped to file #{ret}" if ret
  end

  desc "Restore PostgreSQL Database from local file"
  task "restore" do |_, args|
    arguments = {
      path:          Path[args["path"].to_s],
      host:          (args["host"]? || PlaceOS::PG_HOST).to_s,
      port:          (args["port"]? || PlaceOS::PG_PORT).to_i,
      db:            (args["db"]? || PlaceOS::PG_DB).to_s,
      user:          (args["user"]? || PlaceOS::PG_USER).try &.to_s,
      password:      (args["password"]? || PlaceOS::PG_PASS).to_s,
      force_restore: args["force_restore"]?.try(&.to_s.downcase) == "true" || PlaceOS::PG_FORCE_RESTORE,
    }

    ret = PlaceOS::Utils::PostgresDB.restore(**arguments)
    puts "PostgreSQL database '#{args["db"]}' restored successfully from dump file '#{args["path"]}'" if ret
  end

  desc "Clean PostgreSQL Database by deleting old records"
  task "clean" do |_, args|
    arguments = {
      host:     (args["host"]? || PlaceOS::PG_HOST).to_s,
      port:     (args["port"]? || PlaceOS::PG_PORT).to_i,
      db:       (args["db"]? || PlaceOS::PG_DB).to_s,
      user:     (args["user"]? || PlaceOS::PG_USER).try &.to_s,
      password: (args["password"]? || PlaceOS::PG_PASS).to_s,
      interval: (args["interval"]? || abort "interval is required").to_s,
    }

    PlaceOS::Tasks::CleanUp.cleanup(**arguments)
  end
end

namespace "backup" do
  desc "Generates a PostgreSQL DB backup and writes it to S3"
  task "pg" do |_, args|
    arguments = {
      pg_host:        (args["host"]? || PlaceOS::PG_HOST).to_s,
      pg_port:        (args["port"]? || PlaceOS::PG_PORT).to_i,
      pg_db:          (args["db"]? || PlaceOS::PG_DB).to_s,
      pg_user:        (args["user"]? || PlaceOS::PG_USER).try &.to_s,
      pg_password:    (args["password"]? || PlaceOS::PG_PASS).try &.to_s,
      postfix:        (args["postfix"]? || PlaceOS::PG_DUMP_POSTFIX).to_s,
      aws_region:     (args["aws_region"]? || PlaceOS::AWS_REGION || abort "AWS_REGION unset").to_s,
      aws_key:        (args["aws_key"]? || PlaceOS::AWS_KEY || abort "AWS_KEY unset").to_s,
      aws_secret:     (args["aws_secret"]? || PlaceOS::AWS_SECRET || abort "AWS_SECRET unset").to_s,
      aws_s3_bucket:  (args["aws_s3_bucket"]? || PlaceOS::AWS_S3_BUCKET || abort "AWS_S3_BUCKET unset").to_s,
      aws_kms_key_id: (args["aws_kms_key_id"]? || PlaceOS::AWS_KMS_KEY_ID).try &.to_s,
    }

    PlaceOS::Tasks.pg_backup(**arguments)
  end
  desc "Generates a PostgreSQL DB backup and writes it to Azure Blob Storage"
  task "az" do |_, args|
    arguments = {
      pg_host:      (args["host"]? || PlaceOS::PG_HOST).to_s,
      pg_port:      (args["port"]? || PlaceOS::PG_PORT).to_i,
      pg_db:        (args["db"]? || PlaceOS::PG_DB).to_s,
      pg_user:      (args["user"]? || PlaceOS::PG_USER).try &.to_s,
      pg_password:  (args["password"]? || PlaceOS::PG_PASS).try &.to_s,
      postfix:      (args["postfix"]? || PlaceOS::PG_DUMP_POSTFIX).to_s,
      az_account:   (args["az_account"]? || PlaceOS::AZURE_STORAGE_ACCOUNT_NAME).try &.to_s,
      az_key:       (args["az_key"]? || PlaceOS::AZURE_STORAGE_ACCOUNT_KEY).try &.to_s,
      az_connstr:   (args["az_connstr"]? || PlaceOS::AZURE_STORAGE_CONNECTION_STRING).try &.to_s,
      az_container: (args["az_container"]? || PlaceOS::AZURE_STORAGE_CONTAINER || abort "AZURE_STORAGE_CONTAINER unset").to_s,
    }
    abort "AZURE_STORAGE_XXXX unset. Use either of az_account/az_key or az_connstr" unless ((arguments["az_account"]? && arguments["az_key"]?) || arguments["az_connstr"])

    PlaceOS::Tasks.az_backup(**arguments)
  end
end

namespace "restore" do
  desc "Restores PostgreSQL DB from an S3 backup"
  task "pg" do |_, args|
    arguments = {
      pg_host:        (args["host"]? || PlaceOS::PG_HOST).to_s,
      pg_port:        (args["port"]? || PlaceOS::PG_PORT).to_i,
      pg_db:          (args["db"]? || PlaceOS::PG_DB).to_s,
      pg_user:        (args["user"]? || PlaceOS::PG_USER).to_s,
      pg_password:    (args["password"]? || PlaceOS::PG_PASS).to_s,
      force_restore:  args["force_restore"]?.try(&.to_s.downcase) == "true" || PlaceOS::PG_FORCE_RESTORE,
      aws_region:     (args["aws_region"]? || PlaceOS::AWS_REGION || abort "AWS_REGION unset").to_s,
      aws_key:        (args["aws_key"]? || PlaceOS::AWS_KEY || abort "AWS_KEY unset").to_s,
      aws_secret:     (args["aws_secret"]? || PlaceOS::AWS_SECRET || abort "AWS_SECRET unset").to_s,
      aws_s3_bucket:  (args["aws_s3_bucket"]? || PlaceOS::AWS_S3_BUCKET || abort "AWS_S3_BUCKET unset").to_s,
      aws_s3_object:  (args["aws_s3_object"]? || PlaceOS::AWS_S3_OBJECT || abort "AWS_S3_OBJECT unset").to_s,
      aws_kms_key_id: (args["aws_kms_key_id"]? || PlaceOS::AWS_KMS_KEY_ID).try(&.to_s),
    }

    PlaceOS::Tasks.pg_restore(**arguments)
  end
  desc "Restores PostgreSQL DB from Azure Blob Storage backup"
  task "az" do |_, args|
    arguments = {
      pg_host:        (args["host"]? || PlaceOS::PG_HOST).to_s,
      pg_port:        (args["port"]? || PlaceOS::PG_PORT).to_i,
      pg_db:          (args["db"]? || PlaceOS::PG_DB).to_s,
      pg_user:        (args["user"]? || PlaceOS::PG_USER).try &.to_s,
      pg_password:    (args["password"]? || PlaceOS::PG_PASS).try &.to_s,
      force_restore:  args["force_restore"]?.try(&.to_s.downcase) == "true" || PlaceOS::PG_FORCE_RESTORE,
      az_account:     (args["az_account"]? || PlaceOS::AZURE_STORAGE_ACCOUNT_NAME).try &.to_s,
      az_key:         (args["az_key"]? || PlaceOS::AZURE_STORAGE_ACCOUNT_KEY).try &.to_s,
      az_connstr:     (args["az_connstr"]? || PlaceOS::AZURE_STORAGE_CONNECTION_STRING).try &.to_s,
      az_container:   (args["az_container"]? || PlaceOS::AZURE_STORAGE_CONTAINER || abort "AZURE_STORAGE_CONTAINER unset").to_s,
      az_blob_object: (args["az_blob_object"]? || PlaceOS::AZURE_STORAGE_BLOB_OBJECT || abort "AZURE_STORAGE_BLOB_OBJECT unset").to_s,
    }
    abort "AZURE_STORAGE_XXXX unset. Use either of az_account/az_key or az_connstr" unless ((arguments["az_account"]? && arguments["az_key"]?) || arguments["az_connstr"])

    PlaceOS::Tasks.az_restore(**arguments)
  end
end

namespace "migrate" do
  desc "Migrate RethinkDB dump to PostgreSQL DB"
  task "rethink_dump" do |_, args|
    arguments = {
      path:         args["path"].to_s,
      pg_host:      (args["host"]? || PlaceOS::PG_HOST).to_s,
      pg_port:      (args["port"]? || PlaceOS::PG_PORT).to_i,
      pg_db:        (args["db"]? || PlaceOS::PG_DB).to_s,
      pg_user:      (args["user"]? || PlaceOS::PG_USER).try &.to_s,
      pg_password:  (args["password"]? || PlaceOS::PG_PASS).to_s,
      clean_before: args["clean_before"]?.try(&.to_s.downcase) == "true" || false,
      verbose:      args["verbose"]?.try(&.to_s.downcase) == "true" || false,
    }

    PlaceOS::Tasks.migrate_rethink_to_pg(**arguments)
  end
end

desc "Drops Elasticsearch and PostgreSQL DB"
task "drop", %w[drop:db drop:elastic] do
end

namespace "drop" do
  desc "Deletes all elastic indices tables"
  task "elastic" do |_, args|
    host = (args["host"]? || PlaceOS::ES_HOST).to_s
    port = (args["port"]? || PlaceOS::ES_PORT).to_i
    PlaceOS::Tasks.drop_elastic_indices(host, port)
  end

  desc "Drops all PostgreSQL DB tables"
  task "db" do |_, args|
    arguments = {
      pg_db:       (args["db"]? || PlaceOS::PG_DB).to_s,
      pg_host:     (args["host"]? || PlaceOS::PG_HOST).to_s,
      pg_port:     (args["port"]? || PlaceOS::PG_PORT).to_i,
      pg_user:     (args["user"]? || PlaceOS::PG_USER).try &.to_s,
      pg_password: (args["password"]? || PlaceOS::PG_PASS).try &.to_s,
    }

    PlaceOS::Tasks.drop_pg_tables(**arguments)
  end
end

namespace "check" do
  desc "Check if a user exists on a domain"
  task "user" do |_, args|
    email = required_argument(args, "email").to_s
    domain = required_argument(args, "domain").to_s
    exit(PlaceOS::Tasks.user_exists?(email, domain) ? 0 : 1)
  end
end

namespace "secret" do
  desc "Rotate the instance encryption secret"
  task "rotate_server_secret" do |_, args|
    abort("PLACE_SERVER_SECRET is unset") if ENV["PLACE_SERVER_SECRET"]?.presence.nil?

    old_secret = required_argument(args, "old_secret").to_s
    PlaceOS::Tasks.rotate_secret(old_secret)
  end
end

namespace "create" do
  desc "Generates an instance telemetry key"
  task "instance_key" do
    puts PlaceOS::Tasks.instance_secret_key
  end

  desc "Creates a representative set of documents in PostgreSQL DB"
  task "placeholders" do
    PlaceOS::Tasks.create_placeholders
  end

  desc "Creates an authority"
  task "authority" do |_, args|
    domain_name = (args["domain"]? || PlaceOS::DOMAIN).to_s
    tls = (args["tls"]? || PlaceOS::TLS).try &.to_s.downcase == "true"

    site_origin = "#{tls ? "https" : "http"}://#{domain_name}"
    metrics_url = "#{site_origin}/#{PlaceOS::METRICS_ROUTE}/"
    config = {"metrics" => JSON::Any.new(metrics_url)}
    PlaceOS::Tasks.create_authority(name: domain_name, domain: site_origin, config: config)
  end

  desc "Creates an application"
  task "application" do |_, args|
    arguments = {
      authority:    required_argument(args, "authority").to_s,
      name:         (args["name"]? || "backoffice").to_s,
      base:         (args["base"]? || "http://localhost:8080").to_s,
      redirect_uri: args["redirect_uri"]?.try &.to_s,
      scope:        args["scope"]?.try &.to_s,
    }

    PlaceOS::Tasks.create_application(**arguments)
  end

  desc "Creates a user"
  task "user" do |_, args_hash|
    arguments = {"authority_id", "email", "username", "password"}.map do |arg_key|
      required_argument(args_hash, arg_key).to_s
    end

    sys_admin = args_hash["sys_admin"]?.try &.to_s.downcase == "true"
    support = args_hash["support"]?.try &.to_s.downcase == "true"

    authority_id, email, username, password = arguments

    PlaceOS::Tasks.create_user(
      authority: authority_id,
      name: username,
      email: email,
      password: password,
      sys_admin: sys_admin,
      support: support
    )
  end
end

def required_argument(args, key)
  args[key]? || abort("missing argument `#{key}`")
end

Sam.help

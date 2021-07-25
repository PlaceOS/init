require "sam"

require "./tasks"
require "./constants"

namespace "backup" do
  desc "Generates a RethinkDB backup and writes it to S3"
  task "rethinkdb" do |_, args|
    arguments = {
      rethinkdb_host:     (args["host"]? || PlaceOS::RETHINKDB_HOST).to_s,
      rethinkdb_port:     (args["port"]? || PlaceOS::RETHINKDB_PORT).to_i,
      rethinkdb_db:       (args["db"]? || PlaceOS::RETHINKDB_DB).try &.to_s,
      rethinkdb_password: (args["password"]? || PlaceOS::RETHINKDB_PASS).try &.to_s,
      aws_region:         (args["aws_region"]? || PlaceOS::AWS_REGION || abort "AWS_REGION unset").to_s,
      aws_key:            (args["aws_key"]? || PlaceOS::AWS_KEY || abort "AWS_KEY unset").to_s,
      aws_secret:         (args["aws_secret"]? || PlaceOS::AWS_SECRET || abort "AWS_SECRET unset").to_s,
      aws_s3_bucket:      (args["aws_s3_bucket"]? || PlaceOS::AWS_S3_BUCKET || abort "AWS_S3_BUCKET unset").to_s,
      aws_kms_key_id:     (args["aws_kms_key_id"]? || PlaceOS::AWS_KMS_KEY_ID).try &.to_s,
    }

    PlaceOS::Tasks.rethinkdb_backup(**arguments)
  end
end

namespace "restore" do
  desc "Restores RethinkDB from an S3 backup"
  task "rethinkdb" do |_, args|
    arguments = {
      rethinkdb_host:     (args["host"]? || PlaceOS::RETHINKDB_HOST).to_s,
      rethinkdb_port:     (args["port"]? || PlaceOS::RETHINKDB_PORT).to_i,
      rethinkdb_password: (args["password"]? || PlaceOS::RETHINKDB_PASS).try(&.to_s),
      force_restore:      args["force_restore"]?.try(&.to_s.downcase) == "true" || PlaceOS::RETHINKDB_FORCE_RESTORE,
      aws_region:         (args["aws_region"]? || PlaceOS::AWS_REGION || abort "AWS_REGION unset").to_s,
      aws_key:            (args["aws_key"]? || PlaceOS::AWS_KEY || abort "AWS_KEY unset").to_s,
      aws_secret:         (args["aws_secret"]? || PlaceOS::AWS_SECRET || abort "AWS_SECRET unset").to_s,
      aws_s3_bucket:      (args["aws_s3_bucket"]? || PlaceOS::AWS_S3_BUCKET || abort "AWS_S3_BUCKET unset").to_s,
      aws_s3_object:      (args["aws_s3_object"]? || PlaceOS::AWS_S3_OBJECT || abort "AWS_S3_OBJECT unset").to_s,
      aws_kms_key_id:     (args["aws_kms_key_id"]? || PlaceOS::AWS_KMS_KEY_ID).try(&.to_s),
    }

    PlaceOS::Tasks.rethinkdb_restore(**arguments)
  end
end

desc "Drops Elasticsearch and RethinkDB"
task "drop", %w[drop:db drop:elastic] do
end

namespace "drop" do
  desc "Deletes all elastic indices tables"
  task "elastic" do |_, args|
    host = (args["host"]? || PlaceOS::ES_HOST).to_s
    port = (args["port"]? || PlaceOS::ES_PORT).to_i
    PlaceOS::Tasks.drop_elastic_indices(host, port)
  end

  desc "Drops all RethinkDB tables"
  task "db" do |_, args|
    arguments = {
      rethinkdb_db:   (args["db"]? || PlaceOS::RETHINKDB_DB).to_s,
      rethinkdb_host: (args["host"]? || PlaceOS::RETHINKDB_HOST).to_s,
      rethinkdb_port: (args["port"]? || PlaceOS::RETHINKDB_PORT).to_i,
      user:           (args["user"]? || PlaceOS::RETHINKDB_USER).try &.to_s,
      password:       (args["password"]? || PlaceOS::RETHINKDB_PASS).try &.to_s,
    }

    PlaceOS::Tasks.drop_rethinkdb_tables(**arguments)
  end
end

namespace "check" do
  desc "Check if a user exists on a domain"
  task "user" do |_, args|
    email = (args["email"]? || abort "`email` not set").to_s
    domain = (args["domain"]? || abort "`domain` not set").to_s
    exit(PlaceOS::Tasks.user_exists?(email, domain) ? 0 : 1)
  end
end

namespace "create" do
  desc "Creates a representative set of documents in RethinkDB"
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
      authority:    (args["authority"]? || abort "missing authority id").to_s,
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
      (args_hash[arg_key]?.try &.to_s) || abort "missing argument: `#{arg_key}`"
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

Sam.help

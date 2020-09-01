require "sam"

require "./tasks"
require "./constants"

namespace "backup" do
  desc "Generates a rethinkdb backup and writes it to s3"
  task "rethinkdb" do |_, args|
    rethinkdb_db = (args["db"]? || PlaceOS::RETHINKDB_DB).to_s
    rethinkdb_host = (args["host"]? || PlaceOS::RETHINKDB_HOST).to_s
    rethinkdb_port = (args["port"]? || PlaceOS::RETHINKDB_PORT).to_i
    aws_region = (args["aws_region"]? || PlaceOS::AWS_REGION || abort "AWS_REGION unset").to_s
    aws_key = (args["aws_key"]? || PlaceOS::AWS_KEY || abort "AWS_KEY unset").to_s
    aws_secret = (args["aws_secret"]? || PlaceOS::AWS_SECRET || abort "AWS_SECRET unset").to_s
    aws_s3_bucket = (args["aws_s3_bucket"]? || PlaceOS::AWS_S3_BUCKET || abort "AWS_S3_BUCKET unset").to_s
    aws_kms_key_id = (args["aws_kms_key_id"]? || PlaceOS::AWS_KMS_KEY_ID).try &.to_s

    PlaceOS::Tasks.rethinkdb_backup(
      rethinkdb_db: rethinkdb_db,
      rethinkdb_host: rethinkdb_host,
      rethinkdb_port: rethinkdb_port,
      aws_region: aws_region,
      aws_key: aws_key,
      aws_secret: aws_secret,
      aws_s3_bucket: aws_s3_bucket,
      aws_kms_key_id: aws_kms_key_id,
    )
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
    db = (args["db"]? || PlaceOS::RETHINKDB_DB).to_s
    host = (args["host"]? || PlaceOS::RETHINKDB_HOST).to_s
    port = (args["port"]? || PlaceOS::RETHINKDB_PORT).to_i
    user = (args["user"]? || PlaceOS::RETHINKDB_USER).try &.to_s
    password = (args["password"]? || PlaceOS::RETHINKDB_PASS).try &.to_s
    PlaceOS::Tasks.drop_rethinkdb_tables(
      rethinkdb_db: db,
      rethinkdb_host: host,
      rethinkdb_port: port,
      user: user,
      password: password
    )
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
    tls = (args["tls"]? || TLS).try &.to_s.downcase == "true"

    site_origin = "#{tls ? "https" : "http"}://#{domain_name}"
    PlaceOS::Tasks.create_authority(name: domain_name, domain: site_origin)
  end

  desc "Creates an application"
  task "application" do |_, args|
    authority = (args["authority"]? || abort "missing authority id").to_s
    name = (args["name"]? || "backoffice").to_s
    base = (args["base"]? || "http://localhost:8080").to_s
    redirect_uri = args["redirect_uri"]?.try &.to_s
    scope = args["scope"]?.try &.to_s

    PlaceOS::Tasks.create_application(
      authority: authority,
      name: name,
      base: base,
      redirect_uri: redirect_uri,
      scope: scope,
    )
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

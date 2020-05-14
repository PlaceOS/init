require "sam"

require "./tasks"

desc "Drops Elasticsearch and RethinkDB"
task "drop", %w[drop:db drop:elastic] do
end

namespace "drop" do
  desc "Deletes all elastic indices tables"
  task "elastic" do |_, args|
    host = (args["host"]? || ENV["ES_HOST"]? || "localhost").to_s
    port = (args["port"]? || ENV["ES_PORT"]? || 9200).to_i
    PlaceOS::Tasks.drop_elastic_indices(host, port)
  end

  desc "Drops all RethinkDB tables"
  task "db" do |_, args|
    db = (args["db"]? || ENV["RETHINKDB_DB"]? || "test").to_s
    host = (args["host"]? || ENV["RETHINKDB_HOST"]? || "localhost").to_s
    port = (args["port"]? || ENV["RETHINKDB_PORT"]? || 28015).to_i
    user = (args["user"]? || ENV["RETHINKDB_USER"]?).try &.to_s
    password = (args["password"]? || ENV["RETHINKDB_PASS"]?).try &.to_s
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
    domain_name = (args["domain"]? || ENV["PLACE_DOMAIN"]? || "localhost:8080").to_s
    tls = (args["tls"]? || ENV["PLACE_TLS"]?).try &.to_s.downcase == "true"

    site_origin = "#{tls ? "https" : "http"}://#{domain_name}"
    PlaceOS::Tasks.create_authority(name: domain_name, domain: site_origin)
  end

  desc "Creates an application"
  task "application" do |_, args|
    name = (args["name"]? || "backoffice").to_s
    base = (args["base"]? || "http://localhost:8080").to_s
    PlaceOS::Tasks.create_application(name, base)
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

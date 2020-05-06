require "http/client"
require "rethinkdb"
require "uri"

module PlaceOS::Tasks::Database
  extend self
  include RethinkDB::Shortcuts

  def drop_rethinkdb_tables(
    rethinkdb_db : String,
    rethinkdb_host : String,
    rethinkdb_port : Int32,
    user : String? = nil,
    password : String? = nil
  )
    conn = r.connect(
      host: rethinkdb_host,
      port: rethinkdb_port,
      db: rethinkdb_db,
      user: user,
      password: password,
    )

    # Drop all tables in the db
    r.table_list.for_each do |table|
      r.table(table).delete
    end.run(conn)
  ensure
    conn.close
  end

  def drop_elastic_indices(elastic_host : String, elastic_port : Int32)
    uri = URI.new(
      host: elastic_host,
      port: elastic_port,
      path: "/_all",
      scheme: "http"
    )
    HTTP::Client.delete(uri)
  end
end

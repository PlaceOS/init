require "../logging"

require "http/client"
require "pg-orm"
require "uri"
require "micrate"

module PlaceOS::Tasks::Database
  extend self
  Log = ::Log.for(self)

  def pg_init_database(
    pg_db : String,
    pg_host : String,
    pg_port : Int32,
    pg_user : String? = nil,
    pg_password : String? = nil
  )
    pg_user = "postgres" if pg_user.nil?
    pg_password = "" if pg_password.nil?

    Micrate::DB.connection_url = "postgresql://#{pg_user}:#{pg_password}@#{pg_host}:#{pg_port}/#{pg_db}"
    Micrate::DB.connect do |db|
      Micrate.up(db)
    end
  end

  def drop_pg_tables(
    pg_db : String,
    pg_host : String,
    pg_port : Int32,
    pg_user : String? = nil,
    pg_password : String? = nil
  )
    pg_user = "postgres" if pg_user.nil?
    pg_password = "" if pg_password.nil?

    sql = <<-SQL
      select 'drop table if exists "' || tablename || '" cascade;' from pg_tables
        where schemaname = 'public'
  SQL

    PgORM::Database.configure do |settings|
      settings.host = pg_host
      settings.port = pg_port
      settings.db = pg_db
      settings.user = pg_user
      settings.password = pg_password
    end

    PgORM::Database.exec_sql(sql)
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

require "json"
require "pg-orm"

module PlaceOS::Tasks::CleanUp
  extend self
  Log = ::Log.for(self)

  def cleanup(config : String, host : String, port : Int32, db : String, user : String, password : String)
    Log.info do
      Log.context.set({host: host, port: port, db: db, config: config})
      "cleaning old records"
    end

    unless File.exists?(config)
      Log.error { "config file `#{config}` not found" }
      exit(1)
    end

    PgORM::Database.configure do |settings|
      settings.host = host
      settings.port = port
      settings.db = db
      settings.user = user
      settings.password = password
    end

    tables = TableConfig.from_json(File.read(config))
    tables.each do |table|
      sql = %(
            DELETE FROM #{table.table} WHERE updated_at < NOW() - INTERVAL '#{table.interval}'
        )
      Log.context.set(table: table.table, interval: table.interval)
      Log.info { "Cleaning table" }
      begin
        val = PgORM::Database.exec_sql(sql)
        Log.info { " #{val.rows_affected} rows deleted" }
      rescue ex
        Log.error(exception: ex) { "recieved error when cleaning table '#{table.table}' for interval '#{table.interval}'" }
      end
    end
  end

  record TableConfig, tables : Array(ConfigInfo) do
    include JSON::Serializable
    delegate each, to: @tables
  end

  record ConfigInfo, table : String, interval : String do
    include JSON::Serializable
  end
end

require "json"
require "pg-orm"

module PlaceOS::Tasks::CleanUp
  extend self
  Log = ::Log.for(self)

  def cleanup(interval : String, host : String, port : Int32, db : String, user : String, password : String)
    Log.info do
      Log.context.set({host: host, port: port, db: db, interval: interval})
      "cleaning old records"
    end

    PgORM::Database.configure do |settings|
      settings.host = host
      settings.port = port
      settings.db = db
      settings.user = user
      settings.password = password
    end

    bookings = %(
    DELETE FROM "bookings"WHERE
        (recurrence_type = 'NONE' AND updated_at < NOW() - INTERVAL '#{interval}')
      OR
        (recurrence_type != 'NONE' AND recurrence_end < EXTRACT(EPOCH FROM (NOW() - INTERVAL '#{interval}')))
    )

    event_metadats = %(
    DELETE FROM "event_metadatas"
    WHERE
        (recurring_master_id IS NULL AND resource_master_id IS NULL AND event_end < EXTRACT(EPOCH FROM (NOW() - INTERVAL '#{interval}')))
        OR
        ((recurring_master_id IS NOT NULL OR resource_master_id IS NOT NULL) AND event_end < EXTRACT(EPOCH FROM (NOW() - INTERVAL '#{interval}' * 1.5)))
    )
    tables = ["event_metadatas", "bookings"]
    [event_metadats, bookings].each_with_index do |sql, index|
      table = tables[index]
      Log.context.set(table: table, interval: interval)
      Log.info { "Cleaning table" }
      begin
        val = PgORM::Database.exec_sql(sql)
        Log.info { " #{val.rows_affected} rows deleted" }
      rescue ex
        Log.error(exception: ex) { "recieved error when cleaning table '#{table}'" }
      end
    end
  end
end

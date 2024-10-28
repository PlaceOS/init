module PlaceOS::Utils::PostgresDB
  extend self

  Log = ::Log.for(self)

  def dump(host : String, port : Int32, db : String, user : String, password : String, postfix : String = "") : Path?
    directory = Dir.tempdir
    postfix = "_#{postfix}" unless postfix.blank?

    filename = "#{directory}/postgresql_dump_#{Time.utc.to_unix}#{postfix}.dump.gz"
    arguments = ["-F", "c", "-U", user, "-h", host, "-p", port.to_s, "-d", db, "-Z", "9", "-f", filename]

    output = IO::Memory.new
    ENV["PGPASSWORD"] = password
    result = Process.run("pg_dump", arguments, error: output)

    success = result.exit_code == 0
    Log.error { "postgres dump failed with: #{output}" } unless success
    output.close
    Path[filename] if success
  end

  def restore(path : Path, host : String, port : Int32, db : String, user : String, password : String, force_restore : Bool = false)
    Log.info do
      Log.context.set({path: path.to_s, host: host, port: port, db: db, force_restore: force_restore})
      "restoring"
    end

    if force_restore
      ret = check_n_create(host, port, db, user, password)
      exit(1) unless ret
    end

    arguments = ["-U", user, "-h", host, "-p", port.to_s, "-d", db, path.to_s]

    output = IO::Memory.new
    ENV["PGPASSWORD"] = password
    result = Process.run("pg_restore", arguments, error: output)
    success = result.exit_code == 0
    Log.error { "PostgreSQL restore failed with: #{output}" } unless success
    output.close
    success
  end

  private def check_n_create(host : String, port : Int32, db : String, user : String, password : String)
    template = %(
  DO $$
  BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_database
        WHERE datname = '%s'
    ) THEN
        EXECUTE 'CREATE DATABASE %s';
    END IF;
  END
  $$ LANGUAGE plpgsql;
  )

    sql = sprintf(template, db, db)
    arguments = ["-U", user, "-h", host, "-p", port.to_s, "-d", "postgres", "-c", sql]
    output = IO::Memory.new
    ENV["PGPASSWORD"] = password
    result = Process.run("psql", arguments, error: output)
    success = result.exit_code == 0
    Log.error { "PostgreSQL check and create database failed with: #{output}" } unless success
    output.close
    success
  end
end

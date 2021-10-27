module PlaceOS::Utils::RethinkDB
  extend self

  Log = ::Log.for(self)

  def dump(host : String, port : Int32, db : String? = nil, password : String? = nil) : Path?
    directory = Dir.tempdir

    arguments = ["dump", "-c", "#{host}:#{port}", "-f", "rethinkdb_dump_#{Time.utc.to_unix}.tar.gz"]
    arguments.concat({"-e", db}) unless db.nil?
    arguments.concat({"-p", password}) unless password.nil?

    # Return the file descriptor
    result = ExecFrom.exec_from(directory, "rethinkdb", arguments)
    output = result.output.to_s
    last_line = output.lines.last

    if result.status.success? && last_line.starts_with?("Done")
      file_name = last_line.split(':', limit: 2).last.strip
      Path[file_name]
    else
      Log.error { "rethinkdb dump failed with: #{output}" }
      nil
    end
  end

  def restore(path : Path, host : String, port : Int32, password : String? = nil, force_restore : Bool = false)
    Log.info do
      Log.context.set({path: path.to_s, host: host, port: port, force_restore: force_restore})
      "restoring"
    end

    arguments = ["restore", path.expand.to_s, "-c", "#{host}:#{port}"]
    arguments.concat({"--force"}) if force_restore
    arguments.concat({"-p", password}) unless password.nil?

    # Return the file descriptor

    output = IO::Memory.new
    result = Process.run("rethinkdb", arguments, error: output)

    success = result.exit_code == 0

    Log.error { "rethinkdb restore failed with: #{output}" } unless success

    output.close

    success
  end
end

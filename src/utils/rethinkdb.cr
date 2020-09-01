module PlaceOS::Utils::RethinkDB
  extend self

  def dump(host : String, port : Int32, db : String? = nil, password : String? = nil) : Path?
    directory = Dir.tempdir

    arguments = ["dump", "-c", "#{host}:#{port}"]
    arguments.concat({"-e", db}) unless db.nil?
    arguments.concat({"-p", password}) unless password.nil?

    # Return the file descriptor
    result = ExecFrom.exec_from(directory, "rethinkdb", arguments)
    output = result[:output].to_s
    exit_code = result[:exit_code]

    last_line = output.lines.last

    if exit_code != 0 || !last_line.starts_with?("Done")
      Log.error { "rethinkdb dump failed with: #{output}" }
      nil
    else
      _, file_name = last_line.split(':', limit: 2)
      Path[file_name.strip]
    end
  end

  def restore(path : Path, host : String, port : Int32, password : String? = nil)
    arguments = ["restore", path.expand.to_s, "-c", "#{host}:#{port}"]
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

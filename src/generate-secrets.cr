require "base64"
require "crypto/bcrypt/password"
require "openssl_ext"

module PlaceOS::GenerateSecrets
  extend self

  RED   = "\033[0;31m"
  GREEN = "\033[0;32m"
  RESET = "\033[0m"

  INFLUX_KEY_ENV              = ".env.influxdb"
  CHRONOGRAF_TOKEN_SECRET_ENV = ".env.chronograf"
  SECRET_KEY_ENV              = ".env.secret_key"
  PUBLIC_KEY_ENV              = ".env.public_key"
  INSTANCE_TELEMETRY_KEY_ENV  = ".env.instance_telemetry_key"
  ENV_FILE                    = ".env"
  KIBANA_HTPASSWD             = ".htpasswd-kibana"

  def run : Nil
    env = ENV.to_h
    load_env_file(INFLUX_KEY_ENV, env)
    load_env_file(CHRONOGRAF_TOKEN_SECRET_ENV, env)
    load_env_file(SECRET_KEY_ENV, env)
    load_env_file(PUBLIC_KEY_ENV, env)
    load_env_file(INSTANCE_TELEMETRY_KEY_ENV, env)
    load_env_file(ENV_FILE, env, required: true)

    ensure_chronograf_secret(env)
    ensure_influx_keys(env)
    ensure_server_and_jwt_secrets(env)
    ensure_kibana_basic_auth(env)
    ensure_instance_telemetry_key(env)
  end

  private def load_env_file(path : String, env : Hash(String, String), required : Bool = false) : Nil
    unless File.file?(path)
      abort "#{path}: No such file or directory" if required
      return
    end

    File.each_line(path) do |line|
      parsed = parse_env_line(line)
      next unless parsed

      key, value = parsed
      env[key] = value
    end
  end

  private def parse_env_line(line : String) : {String, String}?
    stripped = line.strip
    return nil if stripped.empty? || stripped.starts_with?('#')

    stripped = stripped.lchop("export ").lstrip
    eq_index = stripped.index('=')
    return nil unless eq_index

    key = stripped[0, eq_index].strip
    return nil if key.empty?

    value = stripped[eq_index + 1..].to_s.strip

    if quoted?(value, '"')
      value = value[1...-1]
      value = value.gsub("\\n", "\n").gsub("\\\"", "\"").gsub("\\\\", "\\")
    elsif quoted?(value, '\'')
      value = value[1...-1]
    else
      comment_index = value.index(" #")
      value = value[0, comment_index] if comment_index
      value = value.rstrip
    end

    {key, value}
  end

  private def quoted?(value : String, quote : Char) : Bool
    value.size >= 2 && value.starts_with?(quote) && value.ends_with?(quote)
  end

  private def present?(env : Hash(String, String), key : String) : Bool
    value = env[key]?
    !value.nil? && !value.empty?
  end

  private def ensure_chronograf_secret(env : Hash(String, String)) : Nil
    if !present?(env, "TOKEN_SECRET")
      token_secret = Random::Secure.base64(256)
      File.write(CHRONOGRAF_TOKEN_SECRET_ENV, "TOKEN_SECRET=#{token_secret}\n")
      env["TOKEN_SECRET"] = token_secret
      puts "generated Chrongraf TOKEN_SECRET"
    else
      puts "already generated Chrongraf TOKEN_SECRET"
    end
  end

  private def ensure_influx_keys(env : Hash(String, String)) : Nil
    if !present?(env, "INFLUX_API_KEY") || !present?(env, "INFLUXDB_TOKEN")
      influx_key = Random::Secure.base64(24)
      File.write(INFLUX_KEY_ENV, "INFLUX_API_KEY=#{influx_key}\nINFLUXDB_TOKEN=#{influx_key}\n")
      env["INFLUX_API_KEY"] = influx_key
      env["INFLUXDB_TOKEN"] = influx_key
      puts "generated INFLUX_API_KEY, INFLUXDB_TOKEN"
    else
      puts "already generated INFLUX_API_KEY, INFLUXDB_TOKEN"
    end
  end

  private def ensure_server_and_jwt_secrets(env : Hash(String, String)) : Nil
    if present?(env, "PLACE_SERVER_SECRET") && present?(env, "JWT_PUBLIC") && present?(env, "JWT_SECRET")
      puts "already generated PLACE_SERVER_SECRET, JWT_SECRET and JWT_PUBLIC"
      return
    end

    if present?(env, "PLACE_SERVER_SECRET")
      puts "#{RED}ERROR#{RESET}: the #{SECRET_KEY_ENV} file contains an existing secret."
      puts "Please update the file should look like the following..."
      puts "JWT_SECRET=<existing-instance-secret>"
      puts "SECRET_KEY_BASE=<existing-instance-secret>"
      puts "PLACE_SERVER_SECRET=<existing-instance-secret>"
      puts "SERVER_SECRET=<existing-instance-secret>"
      exit 1
    elsif present?(env, "JWT_SECRET") && !present?(env, "PLACE_SERVER_SECRET")
      puts "#{RED}ERROR#{RESET}: this instance has previously been initialised with a default secret."
      puts "See the #{GREEN}server:rotate_server_secret#{RESET} task here https://github.com/PlaceOS/init#scripts"
      puts "Please contact support@place.technology if you need help."
      exit 1
    end

    private_key_pem = OpenSSL::PKey::RSA.new(4096).to_pem
    public_key_pem = OpenSSL::PKey::RSA.new(private_key_pem).public_key.to_pem

    secret = Base64.strict_encode(private_key_pem)
    jwt_public = Base64.strict_encode(public_key_pem)
    secret_key_base = secret[0, 30]

    File.write(SECRET_KEY_ENV, "JWT_SECRET=#{secret}\nSECRET_KEY_BASE=#{secret_key_base}\nSERVER_SECRET=#{secret}\nPLACE_SERVER_SECRET=#{secret}\n")
    File.write(PUBLIC_KEY_ENV, "JWT_PUBLIC=#{jwt_public}\n")

    env["JWT_SECRET"] = secret
    env["SERVER_SECRET"] = secret
    env["PLACE_SERVER_SECRET"] = secret
    env["JWT_PUBLIC"] = jwt_public

    puts "generated PLACE_SERVER_SECRET, JWT_SECRET and JWT_PUBLIC"
  end

  private def ensure_kibana_basic_auth(env : Hash(String, String)) : Nil
    if File.file?(KIBANA_HTPASSWD)
      puts "already generated kibana basic auth"
      return
    end

    place_password = env["PLACE_PASSWORD"]? || ""
    place_email = env["PLACE_EMAIL"]? || ""
    password_hash = Crypto::Bcrypt::Password.create(place_password, cost: 5).to_s
    File.write(KIBANA_HTPASSWD, "#{place_email}:#{password_hash}\n")

    puts "generated kibana basic auth"
  end

  private def ensure_instance_telemetry_key(env : Hash(String, String)) : Nil
    if present?(env, "PLACE_INSTANCE_TELEMETRY_KEY")
      puts "already generated PLACE_INSTANCE_TELEMETRY_KEY"
      return
    end

    output = IO::Memory.new
    task_env = env.dup
    task_env["LOG_LEVEL"] = "NONE"
    status = Process.run("task", ["create:instance_key"], env: task_env, output: output, error: Process::Redirect::Inherit)
    exit status.exit_code unless status.success?

    prefixed_output = "PLACE_INSTANCE_TELEMETRY_KEY=#{output.to_s.rstrip("\n")}"
    matching_lines = [] of String
    prefixed_output.each_line(chomp: true) do |line|
      matching_lines << line if line.includes?("PLACE_INSTANCE_TELEMETRY_KEY=")
    end
    raise "failed to capture PLACE_INSTANCE_TELEMETRY_KEY" if matching_lines.empty?

    File.write(INSTANCE_TELEMETRY_KEY_ENV, "#{matching_lines.join("\n")}\n")
    puts "generated PLACE_INSTANCE_TELEMETRY_KEY"
  end
end

# Keep argument behavior identical to the shell script (extra args are ignored).
begin
  PlaceOS::GenerateSecrets.run
rescue error
  STDERR.puts(error.message) if error.message
  exit 1
end

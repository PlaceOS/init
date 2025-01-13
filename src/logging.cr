require "placeos-log-backend"
require "log_helper"

module PlaceOS
  ::Log.progname = PlaceOS::APP_NAME

  log_level = PlaceOS.production? ? Log::Severity::Info : Log::Severity::Debug

  backend = if ENV["LOG_LEVEL"]?.try(&.downcase.chomp) == "none"
              ::Log::IOBackend.new(File.open(File::NULL, "w"))
            else
              PlaceOS::LogBackend.log_backend
            end

  ::Log.setup_from_env(
    default_sources: "*",
    default_level: log_level,
    backend: backend
  )
end

require "./constants"

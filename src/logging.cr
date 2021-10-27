require "placeos-log-backend"
require "log_helper"

module PlaceOS::Init::Logging
  ::Log.progname = NAME
  log_level = PlaceOS.production? ? Log::Severity::Info : Log::Severity::Debug
  ::Log.setup_from_env(
    default_sources: "*",
    default_level: log_level,
    backend: PlaceOS::LogBackend.log_backend,
  )
end

require "./constants"

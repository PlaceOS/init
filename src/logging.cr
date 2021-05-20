require "placeos-log-backend"
require "log_helper"

require "./constants"

module PlaceOS::Init::Logging
  ::Log.progname = NAME
  log_level = PlaceOS.production? ? Log::Severity::Info : Log::Severity::Debug
  ::Log.setup("*", log_level, PlaceOS::LogBackend.log_backend)
end

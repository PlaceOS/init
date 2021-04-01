require "placeos-log-backend"
require "log_helper"

PROD = ENV["ENV"]? == "production"
log_level = PROD ? Log::Severity::Info : Log::Severity::Debug
::Log.setup("*", log_level, PlaceOS::LogBackend.log_backend)

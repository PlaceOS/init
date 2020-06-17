require "action-controller/logger"
require "log_helper"

PROD = ENV["ENV"]? == "production"
log_level = PROD ? Log::Severity::Info : Log::Severity::Debug
::Log.setup("*", log_level, ActionController.default_backend)

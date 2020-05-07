require "action-controller/logger"
require "log_helper"

PROD = ENV["ENV"]? == "production"
log_level = PROD ? Log::Severity::Info : Log::Severity::Debug
Log.builder.bind("*", log_level, backend: ActionController.default_backend)

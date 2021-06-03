require "../logging"
require "./entities"

module PlaceOS::Tasks::Initialization
  extend self
  Log = ::Log.for(self)

  # Initialization script
  def start(
    application_name : String,
    domain : String,
    tls : Bool,
    email : String,
    username : String,
    password : String,
    auth_host : String,
    metrics_route : String
  )
    application_base = "#{tls ? "https" : "http"}://#{domain}"
    metrics_url = "#{application_base}/#{metrics_route}/"
    metrics_config = {"metrics" => JSON::Any.new(metrics_url)}
    authority = Entities.create_authority(name: application_name, domain: application_base, config: metrics_config)
    Entities.create_user(authority: authority, name: username, email: email, password: password, sys_admin: true)
    Entities.create_application(authority: authority, name: application_name, base: application_base)

    Entities.create_interface(
      name: "Backoffice",
      folder_name: "backoffice",
      uri: "https://github.com/placeos/backoffice",
      branch: "build/#{PlaceOS::Tasks.production? ? "prod" : "alpha"}",
      description: "Admin interface for PlaceOS",
    )

    unless PlaceOS::Tasks.production?
      Log.info { "creating placeholder documents" }
      Entities.create_placeholders
    end
  end
end

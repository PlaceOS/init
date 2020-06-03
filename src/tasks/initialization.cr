require "./entities"
require "../log"

module PlaceOS::Tasks::Initialization
  extend self
  Log = ::Log.for("tasks").for("initialization")

  # Initialization script
  def start(
    application_name : String,
    domain : String,
    tls : Bool,
    email : String,
    username : String,
    password : String,
    auth_host : String,
    development : Bool
  )
    application_base = "#{tls ? "https" : "http"}://#{domain}"
    authority = Entities.create_authority(name: application_name, domain: application_base)
    Entities.create_user(authority: authority, name: username, email: email, password: password, sys_admin: true)
    Entities.create_application(authority: authority, name: application_name, base: application_base)
    Entities.create_interface(
      name: "Backoffice",
      folder_name: "backoffice",
      uri: "https://github.com/place-labs/backoffice-release",
      description: "Admin interface for PlaceOS",
    )

    if development
      Log.info { "creating placeholder documents" }
      Entities.create_placeholders
    end
  end
end

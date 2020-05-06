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

    response = HTTP::Client.head("http://#{auth_host}/auth/404")
    until response.success?
      Log.info { {message: "waiting for response from Auth container", auth_host: auth_host} }
      sleep 0.5
      response = HTTP::Client.head("http://#{auth_host}/auth/404")
    end

    Log.info { "creating authority" }
    authority = Entities.create_authority(site_name: domain, site_origin: application_base)
    Log.info { "creating user" }
    Entities.create_user(authority: authority, name: username, email: email, password: password, sys_admin: true)
    Log.info { "creating application" }
    Entities.create_application(application_name: application_name, application_base: application_base)

    if development
      Log.info { "creating placeholder documents" }
      Entities.create_placeholders
    end
  end
end

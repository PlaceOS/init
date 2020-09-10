require "placeos-models"
require "placeos-models/spec/generator"
require "uuid"

require "../log"

module PlaceOS::Tasks::Entities
  extend self
  Log = ::Log.for(self)

  def create_authority(
    name : String,
    domain : String
  )
    existing = Model::Authority.find_by_domain(domain)
    unless existing.nil?
      Log.info { {message: "Authority already exists", domain: domain, name: name} }
      return existing
    end

    auth = Model::Authority.new
    auth.name = File.join(domain.lchop("https://").lchop("http://"), name)
    auth.domain = domain
    auth.save!
    Log.info { {message: "created Authority", authority_id: auth.id, name: name, domain: domain} }
    auth
  rescue e
    log_fail("Authority", e)
    raise e
  end

  def create_interface(
    name : String,
    folder_name : String,
    description : String,
    uri : String,
    branch : String = "master",
    commit_hash : String = "HEAD"
  )
    existing = Model::Repository.where(
      repo_type: Model::Repository::Type::Interface,
      folder_name: folder_name.strip.downcase,
    ).first?

    unless existing.nil?
      Log.info { {message: "Frontend already exists", folder_name: folder_name} }
      return existing
    end

    frontend = Model::Repository.new
    frontend.repo_type = Model::Repository::Type::Interface
    frontend.branch = branch
    frontend.commit_hash = commit_hash
    frontend.description = description
    frontend.folder_name = folder_name
    frontend.name = name
    frontend.uri = uri
    frontend.save!

    Log.info { {
      message:       "created Interface Repository",
      repository_id: frontend.id,
      folder_name:   folder_name,
      name:          name,
      branch:        branch,
      commit_hash:   commit_hash,
      uri:           uri,
    } }

    frontend
  rescue e
    log_fail("Interface Repository", e)
    raise e
  end

  def create_user(
    authority : Model::Authority | String,
    name : String? = nil,
    email : String? = nil,
    password : String? = nil,
    sys_admin : Bool = false,
    support : Bool = false
  )
    authority = Model::Authority.find!(authority) if authority.is_a?(String)
    name = "PlaceOS Support (#{authority.name})" if name.nil?
    email = "support@place.tech" if email.nil?
    authority_id = authority.id.as(String)

    existing = Model::User.find_by_email(authority_id, email)
    unless existing.nil?
      Log.info { {message: "User already exists", name: name, email: email, authority_id: authority_id} }
      return existing
    end

    if password.nil? || password.empty?
      password = secure_string(bytes: 8)
      Log.warn { {message: "temporary password generated for #{email} (#{name}). change it ASAP.", password: password} }
    end

    user = Model::User.new
    user.name = name
    user.sys_admin = sys_admin
    user.support = support
    user.authority_id = authority_id
    user.email = email
    user.password = password

    user.save!
    Log.info { {message: "Admin user created", email: email, site_name: authority.name, authority_id: authority.id} }
    user
  rescue e
    log_fail("Admin user", e)
    raise e
  end

  def create_application(
    authority : Model::Authority | String,
    name : String,
    base : String,
    redirect_uri : String? = nil,
    scope : String? = nil
  )
    authority = Model::Authority.find!(authority) if authority.is_a?(String)
    authority_id = authority.id.as(String)

    redirect_uri = File.join(base, name, "oauth-resp.html") if redirect_uri.nil?
    application_id = Digest::MD5.hexdigest(redirect_uri)
    scope = "public" if scope.nil? || scope.empty?

    existing = Model::DoorkeeperApplication.get_all([application_id], index: :uid).first?
    unless existing.nil?
      Log.info { {message: "Application already exists", name: name, base: base} }
      return existing
    end

    Log.info { {
      message:      "creating Application",
      name:         name,
      base:         base,
      scope:        scope,
      redirect_uri: redirect_uri,
    } }

    application = Model::DoorkeeperApplication.new

    # Required as we are setting a custom database id
    application._new_flag = true

    application.name = name
    application.secret = secure_string(bytes: 48)
    application.redirect_uri = redirect_uri
    application.id = application_id
    application.uid = application_id
    application.scopes = scope
    application.skip_authorization = true
    application.owner_id = authority_id

    application.save!
    Log.info { {
      message:        "created Application",
      name:           application.name,
      application_id: application.id,
      base:           base,
      scope:          scope,
      redirect_uri:   redirect_uri,
    } }
    application
  rescue e
    log_fail("Application", e)
    raise e
  end

  # ameba:disable Metrics/CyclomaticComplexity
  def create_placeholders
    version = UUID.random.to_s.split('-').first

    private_repository_uri = "https://github.com/placeos/private-drivers"
    private_repository_name = "Private Drivers"
    private_repository_folder_name = "private-drivers"

    existing_private_repository = Model::Repository.where(
      uri: private_repository_uri,
      name: private_repository_name,
      folder_name: private_repository_folder_name,
    ).first?

    private_repository = if existing_private_repository.nil?
                           # Private Repository metadata
                           repo = Model::Generator.repository(type: Model::Repository::Type::Driver)
                           repo.uri = private_repository_uri
                           repo.name = private_repository_name
                           repo.folder_name = private_repository_folder_name
                           repo.description = "PlaceOS Private Drivers"
                           repo.save!
                           Log.info { "created private_drivers Repository<#{repo.id}>" }
                           repo
                         else
                           Log.info { "using existing private_repository Repository<#{existing_private_repository.id}>" }
                           existing_private_repository
                         end

    drivers_repository_uri = "https://github.com/placeos/drivers"
    drivers_repository_name = "Drivers"
    drivers_repository_folder_name = "drivers"

    existing_drivers_repository = Model::Repository.where(
      uri: drivers_repository_uri,
      name: drivers_repository_name,
      folder_name: drivers_repository_folder_name,
    ).first?

    if existing_drivers_repository.nil?
      # Drivers Repository metadata
      repo = Model::Generator.repository(type: Model::Repository::Type::Driver)
      repo.uri = "https://github.com/placeos/drivers"
      repo.name = "Drivers"
      repo.folder_name = "drivers"
      repo.description = "PlaceOS Drivers"
      repo.save!
      Log.info { "created drivers Repository<#{repo.id}>" }
      repo
    else
      Log.info { "using existing drivers Repository<#{existing_drivers_repository.id}>" }
    end

    existing_driver = Model::Driver.all.first?

    driver = if existing_driver.nil?
               # Driver metadata
               driver_file_name = "drivers/place/private_helper.cr"
               driver_module_name = "PrivateHelper"
               driver_name = "spec_helper"
               driver_role = Model::Driver::Role::Logic
               new_driver = Model::Driver.new(
                 name: driver_name,
                 role: driver_role,
                 commit: "HEAD",
                 module_name: driver_module_name,
                 file_name: driver_file_name,
               )

               new_driver.repository = private_repository
               new_driver.save!
               Log.info { "created Driver<#{new_driver.id}>" }
               new_driver
             else
               Log.info { "using existing Driver<#{existing_driver.id}>" }
               existing_driver
             end

    existing_zone = Model::Zone.all.first?

    zone = if existing_zone.nil?
             # Zone metadata
             zone_name = "TestZone-#{version}"
             new_zone = Model::Zone.new(name: zone_name)
             new_zone.save!
             Log.info { "created Zone<#{new_zone.id}>" }
             new_zone
           else
             Log.info { "using existing Zone<#{existing_zone.id}>" }
             existing_zone
           end

    existing_control_system = Model::ControlSystem.all.first?
    control_system = if existing_control_system.nil?
                       # ControlSystem metadata
                       control_system_name = "TestSystem-#{version}"
                       new_control_system = Model::ControlSystem.new(name: control_system_name)
                       new_control_system.save!
                       Log.info { "created ControlSystem<#{new_control_system.id}>" }
                       new_control_system
                     else
                       Log.info { "using existing ControlSystem<#{existing_control_system.id}>" }
                       existing_control_system
                     end

    existing_settings = Model::Settings.for_parent(control_system.id.as(String)).first?
    # Check for existing settings on the ControlSystem
    if existing_settings.nil?
      # Settings metadata
      settings_string = %(test_setting: true)
      settings_encryption_level = Encryption::Level::None
      settings = Model::Settings.new(encryption_level: settings_encryption_level, settings_string: settings_string)
      settings.control_system = control_system
      settings.save!
      Log.info { "created Settings<#{settings.id}>" }
      settings
    else
      Log.info { "using existing Settings<#{existing_settings.id}>" }
    end

    existing_module = Model::Module.all.first?

    mod = if existing_module.nil?
            # Module metadata
            module_name = "TestModule-#{version}"
            new_module = Model::Generator.module(driver: driver, control_system: control_system)
            new_module.custom_name = module_name
            new_module.save!
            Log.info { "created Module<#{new_module.id}>" }
            new_module
          else
            Log.info { "using existing Module<#{existing_module.id}>" }
            existing_module
          end

    # Update subarrays of ControlSystem
    control_system.add_module(mod.id.as(String))
    control_system.zones = control_system.zones.as(Array(String)) | [zone.id.as(String)]
    control_system.save!

    existing_trigger = Model::Trigger.all.first?
    trigger = if existing_trigger.nil?
                # Trigger metadata
                trigger_name = "TestTrigger-#{version}"
                trigger_description = "a test trigger"
                new_trigger = Model::Trigger.new(name: trigger_name, description: trigger_description)
                new_trigger.control_system = control_system
                new_trigger.save!
                Log.info { "created Trigger<#{new_trigger.id}>" }
                new_trigger
              else
                Log.info { "using existing Trigger<#{existing_trigger.id}>" }
                existing_trigger
              end

    existing_trigger_instance = Model::TriggerInstance.of(trigger.id.as(String)).first?
    if existing_trigger_instance.nil?
      # TriggerInstance
      trigger_instance = Model::TriggerInstance.new
      trigger_instance.control_system = control_system
      trigger_instance.zone = zone
      trigger_instance.trigger = trigger
      trigger_instance.save!
      Log.info { "created TriggerInstance<#{trigger_instance.id}>" }
    else
      Log.info { "using existing TriggerInstance<#{existing_trigger_instance.id}>" }
    end
  rescue e
    log_fail("Placeholder", e)
    raise e
  end

  def create_broker(
    name : String,
    description : String,
    host : String,
    port : Int32 = 1883, # Default MQTT port for non-tls connections
    tls : Bool = false,
    username : String? = nil,
    password : String? = nil,
    certificate : String? = nil,
    auth_type : AuthType = Model::AuthType::UserPassword,
    secret : String? = nil,
    filters : Array(String)? = nil
  )
    broker = Model::Broker.new(
      name: name,
      description: description,
      host: host,
      port: port,
      tls: port,
      auth_type: auth_type,
    )

    broker.secret = secret unless secret.nil?
    broker.filters = filers unless filters.nil?
    broker.certificate = certificate unless certificate.nil?
    broker.username = username unless username.nil?
    broker.password = password unless password.nil?
  rescue e
    log_fail("Broker", e)
    raise e
  end

  private def log_fail(type : String, exception : Exception)
    Log.error(exception: exception) {
      Log.context.set(model: exception.model.class.name, model_errors: exception.inspect_errors) if exception.is_a?(RethinkORM::Error::DocumentInvalid)
      "#{type} creation failed with: #{exception.inspect_with_backtrace}"
    }
  end

  private def secure_string(bytes : Int32)
    Random::Secure.hex(bytes)
  end
end

require "models"
require "models/spec/generator"
require "uuid"

require "../log"

module PlaceOS::Tasks::Entities
  extend self
  def create_authority(
    site_name : String,
    site_origin : String
  )
    auth = Model::Authority.new
    auth.name = site_name
    auth.domain = site_origin
    auth.save!
    Log.info { {message: "created Authority", authority_id: auth.id, site_name: site_name, site_origin: site_origin} }
  rescue e
    Log.error(exception: e) {
      Log.context.set(model: e.model.class.name, model_errors: e.model.inspect_errors) if e.is_a?(RethinkORM::Error::DocumentInvalid)
      "Authority creation failed with: #{e.inspect_with_backtrace}"
    }
  end

  def create_admin_user(
    authority : Model::Authority | String,
    name : String? = nil,
    email : String? = nil,
    password : String? = nil,
    sys_admin : Bool = false,
    support : Bool = false
  )
    name = "PlaceOS Support (#{authority.name})" if name.nil?
    email = "support@place.tech" if email.nil?
    authority_id = authority.is_a?(String) ? authority : authority.id.as(String)

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
    user.password_confirmation = password

    user.save!
    Log.info { {message: "Admin user created", email: email, site_name: authority.name, authority_id: authority.id} }
    user
  rescue e
    Log.error(exception: e) {
      Log.context.set(model: e.model.class.name, model_errors: e.model.inspect_errors) if e.is_a?(RethinkORM::Error::DocumentInvalid)
      "Admin user creation failed with: #{e.inspect_with_backtrace}"
    }
    raise e
  end

  def create_application(
    application_name : String,
    application_base : String,
    scope : String? = nil
  )
    redirect_uri = "#{app_base}/oauth-resp.html"
    application_id = Digest::MD5.hexdigest(redirect_uri)
    scope = "public" if scope.nil? || scope.empty?

    Log.info { {
      message:          "creating Application",
      application_name: application_name,
      application_base: application_base,
      scope:            scope,
      redirect_uri:     redirect_uri,
    } }

    application = Model::DoorkeeperApplication.new
    application.name = application_name
    application.secret = secure_string(bytes: 48)
    application.redirect_uri = redirect_uri
    application.id = application_id
    application.uid = application_id
    application.scopes = scope
    application.skip_authorization = true

    application.save!
    Log.info { {
      message:          "created Application",
      application_name: application.name,
      application_id:   application.id,
      application_base: application_base,
      scope:            scope,
      redirect_uri:     redirect_uri,
    } }
    application
  rescue e
    Log.error(exception: e) {
      Log.context.set(model: e.model.class.name, model_errors: e.model.inspect_errors) if e.is_a?(RethinkORM::Error::DocumentInvalid)
      "Application creation failed with: #{e.inspect_with_backtrace}"
    }
  end

  def placeholder_documents
    version = UUID.random.to_s.split('-').first

    # Private Repository metadata
    private_repository = Model::Generator.repository(type: Model::Repository::Type::Driver)
    private_repository.uri = "https://github.com/placeos/private-drivers"
    private_repository.name = "Private Drivers"
    private_repository.folder_name = "private-drivers"
    private_repository.description = "PlaceOS Private Drivers"
    private_repository.save!

    # Drivers Repository metadata
    drivers_repository = Model::Generator.repository(type: Model::Repository::Type::Driver)
    drivers_repository.uri = "https://github.com/placeos/drivers"
    drivers_repository.name = "Drivers"
    drivers_repository.folder_name = "drivers"
    drivers_repository.description = "PlaceOS Drivers"
    drivers_repository.save!

    # Driver metadata
    driver_file_name = "drivers/place/private_helper.cr"
    driver_module_name = "PrivateHelper"
    driver_name = "spec_helper"
    driver_role = Model::Driver::Role::Logic
    driver = Model::Driver.new(
      name: driver_name,
      role: driver_role,
      commit: "4be0571",
      module_name: driver_module_name,
      file_name: driver_file_name,
    )

    driver.repository = private_repository
    driver.save!

    # Zone metadata
    zone_name = "TestZone-#{version}"
    zone = Model::Zone.new(name: zone_name)
    zone.save!

    # ControlSystem metadata
    control_system_name = "TestSystem-#{version}"
    control_system = Model::ControlSystem.new(name: control_system_name)
    control_system.save!

    # Settings metadata
    settings_string = %(test_setting: true)
    settings_encryption_level = Encryption::Level::None
    settings = Model::Settings.new(encryption_level: settings_encryption_level, settings_string: settings_string)
    settings.control_system = control_system
    settings.save!

    # Module metadata
    module_name = "TestModule-#{version}"
    mod = Model::Generator.module(driver: driver, control_system: control_system)
    mod.custom_name = module_name
    mod.save!

    # Update subarrays of ControlSystem
    control_system.modules = [mod.id.as(String)]
    control_system.zones = [zone.id.as(String)]
    control_system.save!

    # Trigger metadata
    trigger_name = "TestTrigger-#{version}"
    trigger_description = "a test trigger"
    trigger = Model::Trigger.new(name: trigger_name, description: trigger_description)
    trigger.control_system = control_system
    trigger.save!

    # TriggerInstance
    trigger_instance = Model::TriggerInstance.new
    trigger_instance.control_system = control_system
    trigger_instance.zone = zone
    trigger_instance.trigger = trigger
    trigger_instance.save!
  rescue e
    Log.error(exception: e) {
      Log.context.set(model: e.model.class.name, model_errors: e.model.inspect_errors) if e.is_a?(RethinkORM::Error::DocumentInvalid)
      "Application creation failed with: #{e.inspect_with_backtrace}"
    }
  end

  private def secure_string(bytes : Int32)
    Random::Secure.base64(bytes).rstrip('=')
  end
end

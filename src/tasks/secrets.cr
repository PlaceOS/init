require "ed25519"

module PlaceOS::Tasks::Secrets
  extend self
  Log = ::Log.for(self)

  def instance_secret_key
    # Sodium::Sign::SecretKey.new.key.hexstring
    Ed25519::SigningKey.new.key_bytes.hexstring
  end

  macro update_secret(old_secret, model, field, level, id)
    %value = {{ model }}.{{ field.id }}
    begin
      unless %value.nil?
        %secret = Encryption.decrypt(
          string: %value,
          level: {{ level }},
          id: {{ id }},
          secret: {{ old_secret }},
        )
        {{ model }}.{{ field.id }} = %secret
        # Incomplete sanity check that the value was correctly decrypted
        if %secret.valid_encoding?
          {{ model }}.save!
        else
          Log.warn { "incorrectly decrypted secret for #{{{ model }}.id}" }
        end
      end
    rescue error
      Log.error(exception: error) { "failed to decrypt secret on #{{{ model }}.id}" }
    end
  end

  def rotate_secret(old_secret : String)
    Model::Settings.all.each do |model|
      level = model.encryption_level
      encryption_id = model.parent_id.as(String)
      update_secret(old_secret, model, settings_string, level, encryption_id)
    end

    Model::Repository.all.each do |model|
      encryption_id = model.id.as(String)
      update_secret(old_secret, model, password, Encryption::Level::NeverDisplay, encryption_id)
    end
  end
end

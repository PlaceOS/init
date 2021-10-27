require "sodium"

module PlaceOS::Tasks::Secrets
  extend self
  Log = ::Log.for(self)

  def instance_secret_key
    Sodium::Sign::SecretKey.new.key.hexstring
  end
end

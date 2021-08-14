require "../migration"
require "digest/sha256"

module Migrations::EmailDigest
  include Migration::Irreversible

  def self.up
    PlaceOS::Model::User.all.each do |user|
      digest = PlaceOS::Model::User.digest(user.email)
      user.update_fields(email_digest: digest) unless user.email_digest == digest
    end
  end
end

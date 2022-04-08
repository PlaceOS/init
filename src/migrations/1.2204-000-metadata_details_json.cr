require "../migration"

module Migrations::MetadataJsonDetails
  include Migration::Irreversible

  def self.up
    PlaceOS::Model::Metadata.table_query do |q|
      q
        .filter { |metadata| metadata["details"].type_of.eq("STRING") }
        .update { |metadata| ({"details" => r.json(metadata["details"])}) }
    end
  rescue e
    Log.error(exception: e) { "failed to migrate Metadata.details to JSON" }
  end
end

require "../migration"

module RethinkDB
  def self.json(json_string)
    DatumTerm.new(TermType::JSON, [json_string])
  end
end

module Migrations::MetadataJsonDetails
  include Migration::Irreversible

  def self.up
    PlaceOS::Model::Metadata.table_query do |q|
      q
        .filter(&.["details"].type_of.eq("STRING"))
        .update { |metadata| ({"details" => r.json(metadata["details"].coerce_to("string"))}) }
    end
  rescue e
    Log.error(exception: e) { "failed to migrate Metadata.details to JSON" }
  end
end

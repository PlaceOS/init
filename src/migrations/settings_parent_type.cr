require "../migration"

module Migrations::SettingParentType
  include Migration::Irreversible

  def self.up
    raw_query do |r|
      r
        .table(PlaceOS::Model::Settings.table_name)
        .filter { |s| s["parent_type"].type_of.eq("NUMBER") }
        .update { |s|
          {% begin %}
            r.branch(
              {% for t in PlaceOS::Model::Settings::ParentType.constants %}
                s["parent_type"].eq(PlaceOS::Model::Settings::ParentType::{{t}}.to_i),
                {:parent_type => PlaceOS::Model::Settings::ParentType::{{t}}.to_json},
              {% end %}
            nil
            )
          {% end %}
        }
    end
  end
end

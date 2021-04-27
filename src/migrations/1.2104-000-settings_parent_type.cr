require "../migration"

module Migrations::SettingParentType
  include Migration::Irreversible

  def self.up
    raw_query do |r|
      r
        .table(PlaceOS::Model::Settings.table_name)
        .filter(&.["parent_type"].type_of.eq("NUMBER"))
        .update { |s|
          {% begin %}
            {% type = PlaceOS::Model::Settings::ParentType %}
            r.branch(
              {% for t in type.constants %}
                s["parent_type"].eq({{type}}::{{t}}.to_i),
                {:parent_type => JSON.parse({{type}}::{{t}}.to_json)},
              {% end %}
            nil
            )
          {% end %}
        }
    end
  end
end

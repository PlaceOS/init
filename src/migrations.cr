require "./migrations/*"

module Migrations
  macro finished
    def self.apply_all
      {% for migration in Migration.includers %}
        # FIXME: run version diffing for direction. Up only for now.
        {{migration}}.up
      {% end %}
    end
  end
end


require "rethinkdb-orm"
require "rethinkdb-orm/lock"

require "./migrations/*"

module Migrations
  def self.apply_all
    RethinkORM::Lock.new("placeos-migrations").synchronize do
      {% for migration in Migration.includers.sort_by &.constant(:Ref) %}
        # FIXME: run version diffing for direction. Up only for now.
        {{migration}}.up
      {% end %}
    end
  end
end

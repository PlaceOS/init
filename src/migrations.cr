require "micrate"
require "pg"
require "pg-orm"
require "./migration"
require "./constants"

module Migrations
  # def self.apply_all
  #   Micrate::DB.connection_url = PlaceOS::PG_DATABASE_URL
  #   Micrate::DB.connect do |db|
  #     Micrate.up(db)
  #   end
  #   apply_migrations
  # end

  #  def self.apply_migrations
  def self.apply_all
    PgORM::PgAdvisoryLock.new("placeos-migrations").synchronize do
      {% for migration in Migration.includers.sort_by &.constant(:Ref) %}
        # FIXME: run version diffing for direction. Up only for now.
        {{migration}}.up
      {% end %}
    end
  end
end

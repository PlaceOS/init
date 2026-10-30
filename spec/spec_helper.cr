require "spec"
require "placeos-models"
require "placeos-models/spec/generator"
require "../src/tasks/desk_assets"

PgORM::Database.configure { |_| }

def clear_tables
  PgORM::Database.exec_sql <<-SQL
    TRUNCATE "asset", "asset_type", "asset_category", "metadata", "zone",
      "booking_instances", "bookings", "tenants", "authority", "history" CASCADE
    SQL
end

Spec.before_suite do
  Log.setup(:warn)
  clear_tables
end

Spec.before_each { clear_tables }

require "../migration"

module Migrations::CleanupDoorkeeperGrants
  include Migration::Irreversible

  def self.up
    raw_query do |r|
      r
        .table("doorkeeper_grant")
        .filter(r.row.hasFields("ttl").not)
        .delete
    end
  rescue e
    Log.error(exception: e) { "failed to remove doorkeeper grants without a ttl" }
  end
end

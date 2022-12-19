require "../migration"

module Migrations::CleanupDoorkeeperGrants
  include Migration::Irreversible

  def self.up
    raw_query do |r|
      r.exec "delete from doorkeeper_grant where ttl is null"
    end
  rescue e
    Log.error(exception: e) { "failed to remove doorkeeper grants without a ttl" }
  end
end

require "placeos-models"
require "./logging"

module Migration
  macro included
    Log = ::Log.for(self)

    def self.raw_query(&)
      results = PlaceOS::Model::Connection.raw { |r| yield r }
      Log.info { results }
      results
    rescue e
      Log.error(exception: e) { "Migration failed" }
      raise e
    end
  end
end

module Migration::Irreversible
  macro included
    include Migration
  end

  abstract def up
end

module Migration::Reversible
  macro included
    include Migration
  end

  abstract def up

  abstract def down
end

require "pg-orm"
require "placeos-models"

module Migration
  macro included
    Log = ::Log.for(self)

    Ref = __FILE__

    def self.raw_query(&)
      results = PgORM::Database.connection { |db| yield db }
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

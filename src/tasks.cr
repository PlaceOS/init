require "./constants"
require "./tasks/*"

module PlaceOS::Tasks
  extend self

  include Backup
  include Database
  include Entities
  include Initialization
  include Restore
  include Secrets

  def production?
    PROD
  end
end

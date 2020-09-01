require "./constants"
require "./tasks/*"

module PlaceOS::Tasks
  extend self
  include Backup
  include Database
  include Entities
  include Initialization
  include Restore

  def production?
    PROD
  end
end

require "./constants"
require "./tasks/*"

module PlaceOS::Tasks
  extend self
  include Database
  include Entities
  include Initialization

  def production?
    PROD
  end
end

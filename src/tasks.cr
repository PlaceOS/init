require "./tasks/*"

module PlaceOS::Tasks
  extend self
  include Database
  include Entities
  include Initialization
end

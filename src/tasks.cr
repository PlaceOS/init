require "./tasks/*"

module PlaceOS::Tasks
  include Database
  include Entities
  include Initialization
end

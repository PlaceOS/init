require "./tasks/*"

module PlaceOS::Tasks
  extend self
  include Database
  include Entities
  include Initialization

  PROD = (ENV["ENV"]? || ENV["SG_ENV"]?) == "production"

  def production?
    PROD
  end
end

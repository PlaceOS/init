module PlaceOS
  # Raised when micrate reports that a migration did not apply cleanly.
  class MigrationError < Exception
  end

  # micrate rolls back the transaction, logs the failure and returns `:error`
  # rather than raising, so the result of every call has to be checked. An
  # unchecked call leaves a failed migration looking like a success and the
  # process exiting 0.
  def self.check_migration!(result, action : String) : Nil
    return unless result == :error
    raise MigrationError.new("#{action} failed, see the log above for the underlying error")
  end
end

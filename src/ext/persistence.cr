# nodoc:
module PgORM::Persistence
  private def __create(**options)
    builder = Query::Builder.new(table_name, primary_key.to_s)
    adapter = Database.adapter(builder)

    Database.transaction do
      raise PgORM::Error::RecordInvalid.new(self) unless valid?
      attributes = self.persistent_attributes
      attributes.delete(primary_key) unless self.id?
      begin
        adapter.insert(attributes) do |rid|
          set_primary_key_after_create(rid) unless self.id?
          clear_changes_information
          self.new_record = false
        end
      rescue ex : Exception
        raise PgORM::Error::RecordNotSaved.new("Failed to create record. Reason: #{ex.message}")
      end
    end
    self
  end
end

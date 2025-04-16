# nodoc:
module PgORM::Persistence
  private def __create(**options)
    builder = Query::Builder.new(table_name, primary_key.first.to_s)
    adapter = Database.adapter(builder)

    Database.transaction do
      raise PgORM::Error::RecordInvalid.new(self) unless valid?
      attributes = self.persistent_attributes
      keys = primary_key
      vals = self.id?
      case vals
      when Nil
        keys.each { |key| attributes.delete(key) }
      when Enumerable
        primary_key.each_with_index { |key, index| attributes.delete(key) if vals[index].nil? }
      end

      begin
        adapter.insert(attributes) do |rid|
          set_primary_key_after_create(rid)
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

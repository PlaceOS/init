require "../migration"

module Migrations::UserIdPrefix
  include Migration::Irreversible

  def self.update(table, key, old_id, new_id)
    raw_query do |r|
      r
        .table(table)
        .filter(&.[key].eq(old_id))
        .update { {key => new_id} }
    end
  end

  def self.up
    PlaceOS::Model::User.raw_query do |q|
      q
        .table(PlaceOS::Model::User.table_name)
        .filter do |user|
          user["id"].match("^#{PlaceOS::Model::User.table_name}").not
        end
    end.each do |user|
      Log.info { "migrating User's id from #{user.id} to #{PlaceOS::Model::User.table_name}-#{user.id}" }
      new_id = "#{PlaceOS::Model::User.table_name}-#{user.id}"
      old_id = user.id.as(String)

      {
        {PlaceOS::Model::Metadata.table_name, "parent_id"},
        {PlaceOS::Model::AssetInstance.table_name, "requester_id"},
        {PlaceOS::Model::ApiKey.table_name, "user_id"},
        {PlaceOS::Model::UserAuthLookup.table_name, "user_id"},
      }.each do |table, key|
        update(table, key, old_id, new_id)
      end

      # Save the user _after_ migration relations.
      # Ensures if there's a failure, subsequent runs will complete correctly.
      user_json = user.to_json
      new_user = PlaceOS::Model::User.from_trusted_json(user_json)
      new_user.id = new_id
      new_user.valid?
      if new_user.errors.size == 1 && new_user.errors[0].field == :email_digest
        new_user.errors.clear
        new_user._new_flag = true
        user.delete
        begin
          new_user.save!
        rescue error
          Log.fatal { "user model error:\n#{user_json}\n---------------\nerrors: #{new_user.errors.map &.to_s}" }
          raise error
        end
      else
        Log.fatal { "invalid user model:\n#{user_json}\n---------------\nerrors: #{new_user.errors.map &.to_s}" }
        raise "invalid user model"
      end
    end
  rescue e
    Log.error(exception: e) { "failed to migrate User to prefixed id" }
  end
end

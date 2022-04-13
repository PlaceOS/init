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
    PlaceOS::Model::User.table_query do |q|
      q.filter do |user|
        user["id"].match("^#{PlaceOS::Model::User.table_name}").not
      end
    end.each do |user|
      Log.info { "migrating User's id from #{user.id} to #{PlaceOS::Model::User.table_name}-#{user.id}" }
      new_id = "#{PlaceOS::Model::User.table_name}-#{user.id}"
      old_id = user.id.as(String)
      user.id = new_id

      {
        {PlaceOS::Model::Metadata.table_name, "parent_id"},
        {PlaceOS::Model::AssetInstance.table_name, "requester_id"},
        {PlaceOS::Model::ApiKey.table_name, "user_id"},
        {PlaceOS::Model::UserAuthLookup.table_name, "user_id"},
        {"authentication", "user_id"},
      }.each do |table, key|
        update(table, key, old_id, new_id)
      end

      # Save the user _after_ migration relations.
      # Ensures if there's a failure, subsequent runs will complete correctly.
      user.save!
    end
  rescue e
    Log.error(exception: e) { "failed to migrate User to prefixed id" }
  end
end

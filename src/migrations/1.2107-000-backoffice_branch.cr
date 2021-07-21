require "../migration"

module Migrations::BackofficeBranch
  include Migration::Irreversible

  BRANCH_NAMES = {
    "build-release" => "build/prod",
    "build-alpha"   => "build/dev",
  }

  def self.up
    PlaceOS::Model::Repository.where(
      uri: "https://github.com/placeos/backoffice"
    ).each do |repo|
      begin
        if new_branch = BRANCH_NAMES[repo.branch]?
          Log.info { "updating #{repo.id} (#{repo.branch} -> #{new_branch})" }
          repo.branch = new_branch
          repo.save!
        end
      rescue e
        Log.error(exception: e) { "migration for #{repo.id} failed" }
      end
    end
  end
end

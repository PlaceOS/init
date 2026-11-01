require "./spec_helper"

module PlaceOS::Tasks
  alias Generator = Model::Generator

  def self.zone(tag : String, parent : Model::Zone? = nil) : Model::Zone
    zone = Model::Zone.new(name: "#{tag}-#{Random::Secure.hex(4)}", tags: Set{tag})
    zone.parent_id = parent.id if parent
    zone.save!
  end

  def self.domain(domain : String, org : Model::Zone?) : Model::Authority
    authority = Generator.authority(domain)
    authority.config["org_zone"] = JSON::Any.new(org.id.as(String)) if org
    authority.save!
  end

  def self.desks(level : Model::Zone, json : String) : Model::Metadata
    Model::Metadata.new(name: "desks", parent_id: level.id.as(String), details: JSON.parse(json)).save!
  end

  def self.desk_booking(tenant : Model::Tenant, desk_id : String, zones : Array(String)) : Model::Booking
    booking = Generator.booking(tenant.id, [desk_id], 1.day.ago, 1.day.ago + 1.hour, booking_type: "desk")
    booking.zones = zones
    booking.save!
  end

  def self.desk_assets : Array(Model::Asset)
    Model::Asset.all.to_a.sort_by!(&.zone_id.to_s)
  end

  def self.short_url(authority : Model::Authority, uri : String) : Model::Shortener
    Generator.shortener(uri, user: Generator.user(authority).save!, authority: authority).save!
  end

  def self.settings(org : Model::Zone) : JSON::Any?
    Model::Metadata.for(org.id.as(String), "settings").first?.try(&.details)
  end

  EXAMPLE_DESKS = <<-JSON
    [
      {
        "id": "desk-6.06.1",
        "name": "6.06.01",
        "notes": "",
        "groups": ["staff"],
        "images": ["https://example.com/desk.png"],
        "map_id": "desk-6.06.1",
        "bookable": true,
        "features": ["Standard Office"],
        "security": "DWN 6.06A",
        "assigned_to": "Charles.Yeo@cdu.edu.au",
        "assigned_name": "Charles Yeo",
        "floorsense_id": "fs-1234",
        "custom": {"colour": "blue"}
      },
      {
        "id": "desk-6.06.2",
        "name": "",
        "notes": "by the window",
        "groups": [],
        "images": [],
        "map_id": "",
        "bookable": false,
        "features": ["Standard Office", 3],
        "security": "",
        "assigned_to": ""
      },
      {"id": "desk-6.06.3", "security": null},
      {"name": "no id"},
      {"id": "desk-6.06.4", "map_id": "desk-6.06.1"}
    ]
    JSON

  describe DeskAssets do
    it "migrates desk metadata into assets for each domain" do
      org = zone("org")
      region = zone("region", org)
      building = zone("building", region)
      level = zone("level", building)
      domain("https://one.example.com", org)
      desks(level, EXAMPLE_DESKS)

      # domain without a region
      org2 = zone("org")
      building2 = zone("building", org2)
      level2 = zone("level", building2)
      domain("https://two.example.com", org2)
      desks(level2, %([{"id": "desk-1"}]))

      # domain without an org_zone is ignored
      ignored = zone("org")
      domain("https://ignored.example.com", nil)
      desks(zone("level", zone("building", ignored)), %([{"id": "desk-2"}]))

      summary = DeskAssets.migrate_desk_assets
      summary.committed?.should be_true
      summary.skipped_authorities.should eq ["ignored.example.com"]

      first = summary.domains.find!(&.org_zone_id.==(org.id))
      first.created.should eq 3
      first.skipped.size.should eq 2

      assets = Model::Asset.where(zone_id: level.id.as(String)).to_a.to_h { |asset| {asset.map_id.as(String), asset} }
      assets.keys.sort!.should eq ["desk-6.06.1", "desk-6.06.2", "desk-6.06.3"]

      desk = assets["desk-6.06.1"]
      desk.identifier.should eq "6.06.01"
      desk.zones.should eq [org.id, region.id, building.id, level.id]
      desk.bookable.should be_true
      desk.assigned_to.should eq "Charles.Yeo@cdu.edu.au"
      desk.assigned_name.should eq "Charles Yeo"
      desk.place_groups.should eq ["staff"]
      desk.features.should eq ["Standard Office"]
      desk.images.should eq ["https://example.com/desk.png"]
      desk.security_system_groups.should eq ["DWN 6.06A"]
      desk.other_data.should eq JSON.parse(%({"floorsense_id": "fs-1234", "custom": {"colour": "blue"}}))

      desk = assets["desk-6.06.2"]
      desk.identifier.should eq "desk-6.06.2"
      desk.bookable.should be_false
      desk.assigned_to.should be_nil
      desk.notes.should eq "by the window"
      desk.other_data.should eq JSON.parse("{}")
      desk.features.should eq ["Standard Office"]
      desk.security_system_groups.should be_empty

      desk = assets["desk-6.06.3"]
      desk.identifier.should eq "desk-6.06.3"
      desk.bookable.should be_true
      desk.security_system_groups.should be_empty

      desk = Model::Asset.find_by(zone_id: level2.id.as(String))
      desk.zones.should eq [org2.id, building2.id, level2.id]
      desk.map_id.should eq "desk-1"
      Model::Asset.count.should eq 4

      # one hidden category and type per migrated authority
      Model::AssetCategory.where(name: DeskAssets::DESKS).count.should eq 2
      Model::AssetCategory.where(name: DeskAssets::DESKS).to_a.all?(&.hidden).should be_true
      summary.domains.map(&.category).should eq ["created", "created"]
      Model::AssetType.where(name: DeskAssets::DESKS).count.should eq 2
    end

    it "reuses an existing _DESKS_ category and type, hiding the category" do
      org = zone("org")
      authority = domain("https://one.example.com", org)
      desks(zone("level", zone("building", org)), %([{"id": "desk-1"}]))

      category = Model::AssetCategory.new(name: DeskAssets::DESKS, authority_id: authority.id).save!
      asset_type = Model::AssetType.new(name: DeskAssets::DESKS, brand: "existing", category_id: category.id).save!

      summary = DeskAssets.migrate_desk_assets
      summary.domains.first.category.should eq "hidden"
      Model::AssetCategory.find(category.id).hidden.should be_true
      Model::AssetCategory.count.should eq 1
      Model::AssetType.count.should eq 1
      Model::Asset.find_by(map_id: "desk-1").asset_type_id.should eq asset_type.id
    end

    it "remaps desk bookings to the new asset ids" do
      tenant = Generator.tenant
      org = zone("org")
      building = zone("building", org)
      level1 = zone("level", building)
      level2 = zone("level", building)
      domain("https://one.example.com", org)
      desks(level1, %([{"id": "desk-1"}, {"id": "shared"}]))
      desks(level2, %([{"id": "shared"}]))

      booking = desk_booking(tenant, "desk-1", [org.id.as(String), building.id.as(String), level1.id.as(String)])
      shared = desk_booking(tenant, "shared", [org.id.as(String), building.id.as(String), level2.id.as(String)])
      stale = desk_booking(tenant, "desk-removed", [org.id.as(String), level1.id.as(String)])
      other = Generator.booking(tenant.id, "desk-1", 1.day.ago, 1.day.ago + 1.hour, booking_type: "parking").save!

      # an occurrence of a recurring booking moved to another desk
      PgORM::Database.exec_sql(<<-SQL, booking.id, booking.booking_start + 1.week.total_seconds.to_i64, tenant.id, booking.booking_start, booking.booking_end)
        INSERT INTO "booking_instances" (id, instance_start, tenant_id, booking_start, booking_end, asset_id, asset_ids, created_at, updated_at)
        VALUES ($1, $2, $3, $4, $5, 'shared', '{shared}', NOW(), NOW())
        SQL

      summary = DeskAssets.migrate_desk_assets
      summary.bookings.total.should eq 3
      summary.bookings.remapped.should eq 2
      summary.bookings.missed.should eq 1
      summary.bookings.missed_ids.should eq Set{"desk-removed"}
      summary.instances.remapped.should eq 1

      desk1 = Model::Asset.find_by(zone_id: level1.id.as(String), map_id: "desk-1")
      shared_on_level2 = Model::Asset.find_by(zone_id: level2.id.as(String), map_id: "shared")
      shared_on_level1 = Model::Asset.find_by(zone_id: level1.id.as(String), map_id: "shared")

      booking = Model::Booking.find(booking.id)
      booking.asset_id.should eq desk1.id
      booking.asset_ids.should eq [desk1.id]

      shared = Model::Booking.find(shared.id)
      shared.asset_id.should eq shared_on_level2.id
      shared.asset_ids.should eq [shared_on_level2.id]

      Model::Booking.find(stale.id).asset_id.should eq "desk-removed"
      Model::Booking.find(other.id).asset_id.should eq "desk-1"

      # the instance is resolved using the parent booking zones (level1)
      PgORM::Database.connection do |db|
        db.query_one(%(SELECT asset_id FROM "booking_instances" WHERE id = $1), booking.id, as: String)
      end.should eq shared_on_level1.id
    end

    it "merges use_assets into the org zone settings" do
      org = zone("org")
      domain("https://one.example.com", org)
      org2 = zone("org")
      domain("https://two.example.com", org2)
      Model::Metadata.new(
        name: "settings",
        parent_id: org2.id.as(String),
        details: JSON.parse(%({"app": {"title": "Place"}, "desks": {"auto_release": true}}))
      ).save!

      # migrated by an earlier version of the task, which wrote `desk.use_assets`
      org3 = zone("org")
      domain("https://three.example.com", org3)
      Model::Metadata.new(
        name: "settings",
        parent_id: org3.id.as(String),
        details: JSON.parse(%({"desk": {"use_assets": true}, "desks": {"use_assets": true}}))
      ).save!
      org4 = zone("org")
      domain("https://four.example.com", org4)
      Model::Metadata.new(
        name: "settings",
        parent_id: org4.id.as(String),
        details: JSON.parse(%({"desk": {"use_assets": true, "other": 1}}))
      ).save!

      summary = DeskAssets.migrate_desk_assets
      settings(org).should eq JSON.parse(%({"desks": {"use_assets": true}}))
      settings(org2).should eq JSON.parse(%({"app": {"title": "Place"}, "desks": {"auto_release": true, "use_assets": true}}))
      settings(org3).should eq JSON.parse(%({"desks": {"use_assets": true}}))
      settings(org4).should eq JSON.parse(%({"desk": {"other": 1}, "desks": {"use_assets": true}}))
      summary.domains.to_h { |domain| {domain.org_zone_id, domain.settings} }.should eq({
        org.id => "created", org2.id => "updated", org3.id => "updated", org4.id => "updated",
      })

      DeskAssets.migrate_desk_assets.domains.map(&.settings).uniq.should eq ["unchanged"]
    end

    it "remaps desk ids in short urls" do
      org = zone("org")
      building1 = zone("building", org)
      building2 = zone("building", org)
      level1 = zone("level", building1)
      level2 = zone("level", building2)
      authority = domain("https://one.example.com", org)
      desks(level1, %([{"id": "desk-6.09.08"}, {"id": "desk-1"}]))
      desks(level2, %([{"id": "desk-6.09.08"}]))

      # another domain with the same desk id
      other_org = zone("org")
      other_authority = domain("https://two.example.com", other_org)
      desks(zone("level", zone("building", other_org)), %([{"id": "desk-1"}]))

      redirect = "https://spacefinder.example.com/redirect/?continue=%2Fworkplace%2F%23%2Fbook%2Fcode%3Fasset_id%3Ddesk-6.09.08%26building_id%3D#{building2.id}%26region_id%3Dzone-region"
      code = short_url(authority, redirect)
      direct = short_url(authority, "https://spacefinder.example.com/workplace/#/book/desk?asset_id=desk-1&date=1")
      other = short_url(other_authority, "https://two.example.com/workplace/#/book/code?asset_id=desk-1")
      ambiguous = short_url(authority, "https://spacefinder.example.com/workplace/#/book/code?asset_id=desk-6.09.08")
      removed = short_url(authority, "https://spacefinder.example.com/workplace/#/book/code?asset_id=desk-removed")
      unrelated = short_url(authority, "https://spacefinder.example.com/workplace/#/explore?zone=#{level1.id}")

      summary = DeskAssets.migrate_desk_assets
      summary.shorteners.total.should eq 5
      summary.shorteners.remapped.should eq 3
      summary.shorteners.missed.should eq 2
      summary.shorteners.missed_ids.should eq Set{"desk-6.09.08", "desk-removed"}

      # the building_id param picks the desk on the right level
      on_building2 = Model::Asset.find_by(zone_id: level2.id.as(String), map_id: "desk-6.09.08")
      code = Model::Shortener.find(code.id)
      code.uri.should eq redirect.sub("desk-6.09.08", on_building2.id.as(String))
      code.name.should eq code.uri

      desk1 = Model::Asset.find_by(zone_id: level1.id.as(String), map_id: "desk-1")
      Model::Shortener.find(direct.id).uri.should eq "https://spacefinder.example.com/workplace/#/book/desk?asset_id=#{desk1.id}&date=1"

      # desk ids are resolved within the short url's authority
      other_desk = Model::Asset.where(map_id: "desk-1").to_a.find!(&.id.!=(desk1.id))
      Model::Shortener.find(other.id).uri.should eq "https://two.example.com/workplace/#/book/code?asset_id=#{other_desk.id}"

      # left unchanged when the desk can't be identified
      Model::Shortener.find(ambiguous.id).uri.should eq ambiguous.uri
      Model::Shortener.find(removed.id).uri.should eq removed.uri
      Model::Shortener.find(unrelated.id).uri.should eq unrelated.uri

      second = DeskAssets.migrate_desk_assets
      second.shorteners.remapped.should eq 0
      second.shorteners.already_migrated.should eq 3
      second.shorteners.missed.should eq 2
    end

    it "can be run multiple times" do
      tenant = Generator.tenant
      org = zone("org")
      level = zone("level", zone("building", org))
      domain("https://one.example.com", org)
      metadata = desks(level, %([{"id": "desk-1", "name": "One"}, {"id": "desk-2"}]))
      desk_booking(tenant, "desk-1", [org.id.as(String), level.id.as(String)])
      desk_booking(tenant, "desk-2", [org.id.as(String), level.id.as(String)])

      first = DeskAssets.migrate_desk_assets
      first.bookings.remapped.should eq 2
      ids = desk_assets.map(&.id)

      # fix some data and run again
      metadata.details = JSON.parse(%([{"id": "desk-1", "name": "Desk One"}, {"id": "desk-2"}]))
      metadata.save!

      second = DeskAssets.migrate_desk_assets
      second.domains.first.created.should eq 0
      second.domains.first.updated.should eq 2
      second.domains.first.settings.should eq "unchanged"
      second.bookings.remapped.should eq 0
      second.bookings.missed.should eq 0
      second.bookings.already_migrated.should eq 2

      desk_assets.map(&.id).should eq ids
      Model::Asset.find_by(map_id: "desk-1").identifier.should eq "Desk One"
      Model::AssetCategory.count.should eq 1
      Model::AssetType.count.should eq 1
    end

    it "rolls back a dry run" do
      tenant = Generator.tenant
      org = zone("org")
      level = zone("level", zone("building", org))
      domain("https://one.example.com", org)
      desks(level, %([{"id": "desk-1"}]))
      booking = desk_booking(tenant, "desk-1", [org.id.as(String), level.id.as(String)])

      summary = DeskAssets.migrate_desk_assets(dry_run: true)
      summary.committed?.should be_false
      summary.domains.first.created.should eq 1
      summary.bookings.remapped.should eq 1

      Model::Asset.count.should eq 0
      Model::AssetCategory.count.should eq 0
      Model::Booking.find(booking.id).asset_id.should eq "desk-1"
      settings(org).should be_nil
    end
  end
end

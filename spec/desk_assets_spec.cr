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
        "assigned_name": "Charles Yeo"
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

      desk = assets["desk-6.06.2"]
      desk.identifier.should eq "desk-6.06.2"
      desk.bookable.should be_false
      desk.assigned_to.should be_nil
      desk.notes.should eq "by the window"
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

      # one category and type per migrated authority
      Model::AssetCategory.where(name: DeskAssets::DESKS).count.should eq 2
      Model::AssetType.where(name: DeskAssets::DESKS).count.should eq 2
    end

    it "reuses an existing _DESKS_ category and type" do
      org = zone("org")
      authority = domain("https://one.example.com", org)
      desks(zone("level", zone("building", org)), %([{"id": "desk-1"}]))

      category = Model::AssetCategory.new(name: DeskAssets::DESKS, authority_id: authority.id).save!
      asset_type = Model::AssetType.new(name: DeskAssets::DESKS, brand: "existing", category_id: category.id).save!

      DeskAssets.migrate_desk_assets
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
        details: JSON.parse(%({"app": {"title": "Place"}, "desk": {"auto_release": true}}))
      ).save!

      DeskAssets.migrate_desk_assets
      settings(org).should eq JSON.parse(%({"desk": {"use_assets": true}}))
      settings(org2).should eq JSON.parse(%({"app": {"title": "Place"}, "desk": {"auto_release": true, "use_assets": true}}))
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

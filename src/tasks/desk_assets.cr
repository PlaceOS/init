require "json"
require "pg-orm"
require "placeos-models"

# Migrates desks from the `desks` metadata on level zones into the asset table,
# remaps desk bookings and short URLs (QR codes) to the new asset ids and enables
# `desks.use_assets` in the org zone settings. Everything is written in a single
# transaction and the task can be re-run: existing assets are matched on
# (asset type, zone_id, map_id).
module PlaceOS::Tasks::DeskAssets
  extend self
  Log = ::Log.for(self)

  DESKS      = "_DESKS_"
  BATCH_SIZE = 1000

  # apps read `app.desks.use_assets` from the org zone `settings` metadata
  SETTINGS_KEY        = "desks"
  LEGACY_SETTINGS_KEY = "desk"

  # url params that can disambiguate a desk id that exists on multiple levels
  LINK_ZONE_PARAMS = {"level_id", "zone_id", "building_id"}

  # desk metadata keys with an asset field, the rest are kept in `other_data`
  MAPPED_KEYS = {"id", "map_id", "name", "bookable", "assigned_to", "assigned_name", "groups", "features", "images", "notes", "security"}

  record Desk,
    legacy_id : String,
    map_id : String,
    identifier : String,
    zone_id : String,
    zones : Array(String),
    bookable : Bool,
    assigned_to : String?,
    assigned_name : String?,
    place_groups : Array(String),
    features : Array(String),
    images : Array(String),
    notes : String?,
    security_system_groups : Array(String),
    other_data : JSON::Any

  # The desks collected for a single authority
  class Domain
    getter authority_id : String
    getter domain : String
    getter org_zone_id : String
    property levels : Int32 = 0
    property levels_with_desks : Int32 = 0
    getter desks = [] of Desk
    getter skipped = [] of String
    property created : Int32 = 0
    property updated : Int32 = 0
    property settings : String = "unchanged"
    property category : String = "unchanged"

    def initialize(@authority_id, @domain, @org_zone_id)
    end
  end

  class RemapStats
    property total : Int32 = 0
    property remapped : Int32 = 0
    property already_migrated : Int32 = 0
    property missed : Int32 = 0
    getter missed_ids = Set(String).new
  end

  class Summary
    getter domains = [] of Domain
    getter skipped_authorities = [] of String
    getter bookings = RemapStats.new
    getter instances = RemapStats.new
    getter shorteners = RemapStats.new
    property? dry_run : Bool = false
    property? committed : Bool = false

    def to_s(io : IO) : Nil
      io << "Desk asset migration " << (dry_run? ? "(dry run, rolled back)" : (committed? ? "(committed)" : "(not committed)")) << '\n'
      io << "  authorities skipped (no org_zone): " << skipped_authorities.size << '\n'
      domains.each do |domain|
        io << "  " << domain.domain << " (" << domain.authority_id << ", org " << domain.org_zone_id << ")\n"
        io << "    levels: " << domain.levels << ", with desks: " << domain.levels_with_desks << '\n'
        io << "    desks: " << domain.desks.size << ", created: " << domain.created << ", updated: " << domain.updated << ", skipped: " << domain.skipped.size << '\n'
        domain.skipped.each { |reason| io << "      skipped " << reason << '\n' }
        io << "    category: " << domain.category << ", settings: " << domain.settings << '\n'
      end
      write_stats(io, "desk bookings", bookings)
      write_stats(io, "booking instances", instances)
      write_stats(io, "short urls", shorteners, "unresolved asset ids")
    end

    private def write_stats(io, label, stats, missed_label = "missed desk ids")
      io << "  " << label << ": " << stats.total << ", remapped: " << stats.remapped
      io << ", already migrated: " << stats.already_migrated << ", missed: " << stats.missed << '\n'
      unless stats.missed_ids.empty?
        io << "    " << missed_label << " (" << stats.missed_ids.size << "): " << stats.missed_ids.first(20).join(", ")
        io << ", ..." if stats.missed_ids.size > 20
        io << '\n'
      end
    end
  end

  def migrate_desk_assets(host : String, port : Int32, db : String, user : String?, password : String?, dry_run : Bool = false) : Summary
    PgORM::Database.configure do |settings|
      settings.host = host
      settings.port = port
      settings.db = db
      settings.user = user || "postgres"
      settings.password = password || ""
    end

    migrate_desk_assets(dry_run).tap { |summary| puts summary }
  end

  def migrate_desk_assets(dry_run : Bool = false) : Summary
    summary = Summary.new
    summary.dry_run = dry_run

    # 1 & 2. collect and prepare
    collect(summary)

    # 3. migrate
    PgORM::Database.transaction do
      lookup = {} of String => Array(Candidate)
      desk_asset_ids = Set(String).new

      summary.domains.each do |domain|
        migrate_domain(domain, lookup, desk_asset_ids)
        enable_assets_setting(domain)
      end

      remap_bookings(lookup, desk_asset_ids, summary.bookings)
      remap_instances(lookup, desk_asset_ids, summary.instances)
      remap_shorteners(lookup, desk_asset_ids, summary.shorteners)

      raise DB::Rollback.new if dry_run
      summary.committed = true
    end

    summary
  rescue error
    Log.error(exception: error) { "desk asset migration failed, rolled back" }
    raise error
  end

  # Collect
  ###############################################################################################

  private record ZoneNode, id : String, parent_id : String?, tags : Array(String)

  protected def collect(summary : Summary) : Nil
    zones = load_zones
    children = Hash(String, Array(ZoneNode)).new { |hash, key| hash[key] = [] of ZoneNode }
    zones.each_value { |zone| zone.parent_id.try { |parent_id| children[parent_id] << zone } }

    Model::Authority.all.each do |authority|
      org_zone_id = authority.config["org_zone"]?.try(&.as_s?).presence
      unless org_zone_id
        summary.skipped_authorities << authority.domain
        next
      end

      domain = Domain.new(authority.id.as(String), authority.domain, org_zone_id)
      summary.domains << domain

      unless zones.has_key?(org_zone_id)
        domain.skipped << "org zone #{org_zone_id}: not found"
        next
      end

      levels = {} of String => Array(String)
      find_levels(zones[org_zone_id], [] of String, children, levels, Set(String).new)
      domain.levels = levels.size

      levels.each do |level_id, branch|
        next unless metadata = Model::Metadata.for(level_id, "desks").first?
        desks = metadata.details.as_a?
        unless desks
          domain.skipped << "level #{level_id}: desks metadata is not an array"
          next
        end

        domain.levels_with_desks += 1
        map_ids = Set(String).new
        desks.each_with_index do |json, index|
          desk = parse_desk(json, level_id, branch)
          if desk.is_a?(String)
            domain.skipped << "level #{level_id} desk #{index}: #{desk}"
          elsif !map_ids.add?(desk.map_id)
            domain.skipped << "level #{level_id} desk #{desk.legacy_id}: duplicate map_id #{desk.map_id}"
          else
            domain.desks << desk
          end
        end
      end
    end
  end

  private def load_zones : Hash(String, ZoneNode)
    zones = {} of String => ZoneNode
    PgORM::Database.connection do |db|
      db.query_each(%(SELECT id, parent_id, tags FROM "zone")) do |rs|
        zone = ZoneNode.new(rs.read(String), rs.read(String?), rs.read(Array(String)?) || [] of String)
        zones[zone.id] = zone
      end
    end
    zones
  end

  # depth first walk of the zone tree, levels are the leaves we are interested in
  private def find_levels(zone : ZoneNode, path : Array(String), children, levels, visited) : Nil
    return unless visited.add?(zone.id)
    branch = path + [zone.id]

    if zone.tags.includes?("level")
      levels[zone.id] = branch
      return
    end

    children[zone.id]?.try &.each { |child| find_levels(child, branch, children, levels, visited) }
  end

  # Prepare
  ###############################################################################################

  # returns the reason for skipping when the desk can't be migrated
  protected def parse_desk(json : JSON::Any, level_id : String, branch : Array(String)) : Desk | String
    desk = json.as_h?
    return "not an object" unless desk

    id = string(desk["id"]?)
    map_id = string(desk["map_id"]?) || id
    return "missing id and map_id" unless map_id
    legacy_id = id || map_id

    Desk.new(
      legacy_id: legacy_id,
      map_id: map_id,
      identifier: string(desk["name"]?) || legacy_id,
      zone_id: level_id,
      zones: branch,
      bookable: desk["bookable"]?.try(&.as_bool?) != false,
      assigned_to: string(desk["assigned_to"]?),
      assigned_name: string(desk["assigned_name"]?),
      place_groups: strings(desk["groups"]?),
      features: strings(desk["features"]?),
      images: strings(desk["images"]?),
      notes: string(desk["notes"]?),
      security_system_groups: string(desk["security"]?).try { |group| [group] } || [] of String,
      other_data: other_data(desk),
    )
  end

  # custom fields, such as third party ids (`floorsense_id`). Always an object
  # so consumers can safely look up keys (a nil is stored as JSON null)
  private def other_data(desk : Hash(String, JSON::Any)) : JSON::Any
    JSON::Any.new(desk.reject { |key, _| MAPPED_KEYS.includes?(key) })
  end

  private def string(value : JSON::Any?) : String?
    value.try(&.as_s?).presence
  end

  private def strings(value : JSON::Any?) : Array(String)
    value.try(&.as_a?).try(&.compact_map(&.as_s?)) || [] of String
  end

  # Migrate
  ###############################################################################################

  private def migrate_domain(domain : Domain, lookup, desk_asset_ids) : Nil
    asset_type = desks_asset_type(domain)
    type_id = asset_type.id.as(String)

    existing = Model::Asset.where(asset_type_id: type_id).to_a
    existing.each { |asset| desk_asset_ids << asset.id.as(String) }
    index = existing.to_h { |asset| { {asset.zone_id, asset.map_id}, asset } }

    domain.desks.each do |desk|
      asset = index[{desk.zone_id, desk.map_id}]?
      if asset
        domain.updated += 1
      else
        asset = Model::Asset.new
        asset.asset_type_id = type_id
        asset.zone_id = desk.zone_id
        asset.map_id = desk.map_id
        domain.created += 1
      end

      asset.identifier = desk.identifier
      asset.zones = desk.zones
      asset.bookable = desk.bookable
      asset.assigned_to = desk.assigned_to
      asset.assigned_name = desk.assigned_name
      asset.place_groups = desk.place_groups
      asset.features = desk.features
      asset.images = desk.images
      asset.notes = desk.notes
      asset.security_system_groups = desk.security_system_groups
      asset.other_data = desk.other_data
      asset.save!

      asset_id = asset.id.as(String)
      desk_asset_ids << asset_id
      (lookup[desk.legacy_id] ||= [] of Candidate) << Candidate.new(asset_id, desk.zone_id, desk.zones, domain.authority_id)
    end
  end

  # the oldest `_DESKS_` category and type, matching how apps and staff-api resolve them.
  # The category is hidden so desks don't appear as generic assets (apps only search hidden categories)
  private def desks_asset_type(domain : Domain) : Model::AssetType
    authority_id = domain.authority_id
    category = Model::AssetCategory.where(authority_id: authority_id, name: DESKS).order(:created_at).first?
    if category.nil?
      category = Model::AssetCategory.new(name: DESKS, authority_id: authority_id, hidden: true).save!
      domain.category = "created"
    elsif !category.hidden
      category.hidden = true
      category.save!
      domain.category = "hidden"
    end

    category_id = category.id.as(String)
    Model::AssetType.where(category_id: category_id, name: DESKS).order(:created_at).first? ||
      Model::AssetType.new(name: DESKS, brand: DESKS, category_id: category_id).save!
  end

  private def enable_assets_setting(domain : Domain) : Nil
    metadata = Model::Metadata.for(domain.org_zone_id, "settings").first?
    domain.settings = metadata ? "updated" : "created"
    metadata ||= Model::Metadata.new(name: "settings", parent_id: domain.org_zone_id, details: JSON::Any.new({} of String => JSON::Any))

    # copies, mutating the existing details in place hides the change from dirty tracking
    details = metadata.details.as_h?.try(&.dup) || {} of String => JSON::Any
    changed = remove_legacy_setting(details)

    desks = details[SETTINGS_KEY]?.try(&.as_h?).try(&.dup)
    unless desks
      Log.warn { "#{domain.org_zone_id} settings.#{SETTINGS_KEY} is not an object, replacing it" } if details.has_key?(SETTINGS_KEY)
      desks = {} of String => JSON::Any
    end

    unless desks["use_assets"]?.try(&.as_bool?) == true
      desks["use_assets"] = JSON::Any.new(true)
      details[SETTINGS_KEY] = JSON::Any.new(desks)
      changed = true
    end

    unless changed
      domain.settings = "unchanged"
      return
    end

    metadata.details = JSON::Any.new(details)
    metadata.save!
  end

  # earlier versions of this task wrote `desk.use_assets`, which apps don't read
  private def remove_legacy_setting(details : Hash(String, JSON::Any)) : Bool
    return false unless legacy = details[LEGACY_SETTINGS_KEY]?.try(&.as_h?)
    return false unless legacy.has_key?("use_assets")

    legacy = legacy.reject("use_assets")
    if legacy.empty?
      details.delete(LEGACY_SETTINGS_KEY)
    else
      details[LEGACY_SETTINGS_KEY] = JSON::Any.new(legacy)
    end
    true
  end

  # Remap bookings
  ###############################################################################################

  # an asset created for a legacy desk id, desk ids are only unique within a level
  private record Candidate, asset_id : String, level_id : String, zones : Array(String), authority_id : String

  private record Row, key : JSON::Any, asset_id : String?, asset_ids : Array(String), zones : Array(String)

  private def remap_bookings(lookup, desk_asset_ids, stats : RemapStats) : Nil
    rows = [] of Row
    PgORM::Database.connection do |db|
      db.query_each(%(SELECT id, asset_id, asset_ids, zones FROM "bookings" WHERE booking_type = 'desk')) do |rs|
        key = JSON::Any.new({"id" => JSON::Any.new(rs.read(Int64))})
        rows << Row.new(key, rs.read(String?), rs.read(Array(String)?) || [] of String, rs.read(Array(String)?) || [] of String)
      end
    end

    remap(rows, lookup, desk_asset_ids, stats, <<-SQL)
      UPDATE "bookings" AS b SET asset_id = u.asset_id, asset_ids = u.asset_ids
      FROM jsonb_to_recordset($1::jsonb) AS u(id bigint, asset_id text, asset_ids text[])
      WHERE b.id = u.id
      SQL
  end

  # occurrences of recurring desk bookings can override the parent booking assets
  private def remap_instances(lookup, desk_asset_ids, stats : RemapStats) : Nil
    rows = [] of Row
    PgORM::Database.connection do |db|
      db.query_each(<<-SQL) do |rs|
        SELECT bi.id, bi.instance_start, bi.asset_id, bi.asset_ids, b.zones
        FROM "booking_instances" AS bi INNER JOIN "bookings" AS b ON b.id = bi.id
        WHERE b.booking_type = 'desk' AND (bi.asset_id IS NOT NULL OR bi.asset_ids IS NOT NULL)
        SQL
        key = JSON::Any.new({"id" => JSON::Any.new(rs.read(Int64)), "instance_start" => JSON::Any.new(rs.read(Int64))})
        rows << Row.new(key, rs.read(String?), rs.read(Array(String)?) || [] of String, rs.read(Array(String)?) || [] of String)
      end
    end

    remap(rows, lookup, desk_asset_ids, stats, <<-SQL)
      UPDATE "booking_instances" AS bi SET asset_id = u.asset_id, asset_ids = u.asset_ids
      FROM jsonb_to_recordset($1::jsonb) AS u(id bigint, instance_start bigint, asset_id text, asset_ids text[])
      WHERE bi.id = u.id AND bi.instance_start = u.instance_start
      SQL
  end

  private def remap(rows : Array(Row), lookup, desk_asset_ids, stats : RemapStats, update_sql : String) : Nil
    updates = [] of JSON::Any

    rows.each do |row|
      stats.total += 1
      legacy_ids = row.asset_ids.empty? ? [row.asset_id].compact : row.asset_ids
      if legacy_ids.empty?
        stats.missed += 1
        next
      end

      if legacy_ids.all? { |id| desk_asset_ids.includes?(id) }
        stats.already_migrated += 1
        next
      end

      asset_ids = legacy_ids.map { |id| resolve(id, row.zones, lookup, desk_asset_ids) }
      if missing = asset_ids.index(nil)
        stats.missed += 1
        stats.missed_ids << legacy_ids[missing]
        next
      end

      resolved = asset_ids.compact
      update = row.key.as_h.dup
      update["asset_id"] = JSON::Any.new(resolved.first)
      update["asset_ids"] = JSON::Any.new(resolved.map { |id| JSON::Any.new(id) })
      updates << JSON::Any.new(update)
      stats.remapped += 1
    end

    updates.each_slice(BATCH_SIZE) do |batch|
      PgORM::Database.connection { |db| db.exec(update_sql, args: [batch.to_json]) }
    end
  end

  # Remap short urls
  ###############################################################################################

  # short urls (typically QR codes) link to desks with an `asset_id` param, e.g.
  # `/redirect/?continue=%2Fworkplace%2F%23%2Fbook%2Fcode%3Fasset_id%3Ddesk-1%26building_id%3Dzone-1`
  private def remap_shorteners(lookup, desk_asset_ids, stats : RemapStats) : Nil
    Model::Shortener.where("uri LIKE ?", "%asset_id%").each do |shortener|
      linked = false
      missed = [] of String

      uri = rewrite_url(shortener.uri) do |id, params|
        linked = true
        next id if desk_asset_ids.includes?(id)
        resolve_link(id, params, shortener.authority_id, lookup).tap { |asset_id| missed << id unless asset_id }
      end
      next unless linked

      stats.total += 1
      stats.missed_ids.concat(missed)
      if uri != shortener.uri
        shortener.name = uri if shortener.name == shortener.uri
        shortener.uri = uri
        shortener.save!
        stats.remapped += 1
      elsif missed.empty?
        stats.already_migrated += 1
      else
        stats.missed += 1
      end
    end
  end

  # rewrites `asset_id` query params, including params nested in other params
  # (`?continue=...`) and in fragment routes (`#/book/code?asset_id=...`).
  # Returns the url unchanged when no `asset_id` changes
  protected def rewrite_url(url : String, &resolve : String, URI::Params -> String?) : String
    head, hash, fragment = url.partition('#')
    head = rewrite_query(head, &resolve)
    hash.empty? ? head : "#{head}##{rewrite_query(fragment, &resolve)}"
  end

  private def rewrite_query(part : String, &resolve : String, URI::Params -> String?) : String
    path, mark, query = part.partition('?')
    return part if mark.empty? || query.empty?

    params = URI::Params.parse(query)
    changed = false
    rewritten = URI::Params.build do |form|
      params.each do |key, value|
        updated = if key == "asset_id"
                    resolve.call(value, params) || value
                  elsif value.includes?('?')
                    rewrite_url(value, &resolve)
                  else
                    value
                  end
        changed ||= updated != value
        form.add key, updated
      end
    end

    changed ? "#{path}?#{rewritten}" : part
  end

  # desk ids are only unique within a level, links usually include the building
  private def resolve_link(id : String, params : URI::Params, authority_id : String?, lookup) : String?
    return unless candidates = lookup[id]?.try(&.select(&.authority_id.==(authority_id)))
    return if candidates.empty?
    return candidates.first.asset_id if candidates.size == 1

    LINK_ZONE_PARAMS.each do |key|
      next unless zone_id = params[key]?
      matches = candidates.select(&.zones.includes?(zone_id))
      return matches.first.asset_id if matches.size == 1
    end
    nil
  end

  # prefer the candidate on one of the booking zones when a desk id exists on multiple levels
  private def resolve(id : String, zones : Array(String), lookup, desk_asset_ids) : String?
    return id if desk_asset_ids.includes?(id)
    return unless candidates = lookup[id]?
    return candidates.first.asset_id if candidates.size == 1
    candidates.find { |candidate| zones.includes?(candidate.level_id) }.try &.asset_id
  end
end

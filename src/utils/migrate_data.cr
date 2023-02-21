require "json"
require "uri"
require "file_utils"
require "crystar"
require "placeos-models"
require "connect-proxy"

module PlaceOS::Utils::DataMigrator
  extend self

  Log = ::Log.for(self)
  alias AfterSaveCB = (String?, String | Int64) ->
  alias OnErrorCB = (JSON::Any, Exception) -> Exception?

  MODELS = [
    {"user", PlaceOS::Model::User},
    {"api_key", PlaceOS::Model::ApiKey},
    {"ass", PlaceOS::Model::AssetInstance},
    {"asset", PlaceOS::Model::Asset},
    {"authority", PlaceOS::Model::Authority},
    {"broker", PlaceOS::Model::Broker},
    {"sys", PlaceOS::Model::ControlSystem},
    {"driver", PlaceOS::Model::Driver},
    {"edge", PlaceOS::Model::Edge},
    {"json_schema", PlaceOS::Model::JsonSchema},
    {"ldap_strat", PlaceOS::Model::LdapAuthentication},
    {"zone", PlaceOS::Model::Zone},
    {"metadata", PlaceOS::Model::Metadata},
    {"oauth_strat", PlaceOS::Model::OAuthAuthentication},
    {"repo", PlaceOS::Model::Repository},
    {"adfs_strat", PlaceOS::Model::SamlAuthentication},
    {"sets", PlaceOS::Model::Settings},
    {"stats", PlaceOS::Model::Statistics},
    {"trigger", PlaceOS::Model::Trigger},
    {"trig", PlaceOS::Model::TriggerInstance},
    {"authentication", PlaceOS::Model::UserAuthLookup},
  ]

  def migrate_rethink(dump : String, uri : String, clear_table = false)
    PgORM::Database.parse(uri)
    file_path = get_file(dump)
    data_dir = decompress_dump(file_path)
    begin
      MODELS.each do |table, cls|
        cls.clear if clear_table
        File.open(Path[data_dir, "#{table}.json"]) do |io|
          load_data(io, cls) { }
        end
      end

      load_mod_data(data_dir, clear_table)
      load_doorkeeper_data(data_dir, clear_table)
    ensure
      FileUtils.rm_rf(data_dir)
    end
  end

  private def load_data(data : IO, model : PgORM::Base.class, after_save : AfterSaveCB? = nil, on_err : OnErrorCB? = nil, &)
    records = JSON.parse(data).as_a
    Log.info { "Loading #{records.size} records into table \"#{model.table_name}\" " }
    return if records.empty?

    success = 0
    errors = Failures.new(model.table_name)
    records.each_with_index do |r, index|
      val = yield r
      row = nil
      begin
        row = model.from_trusted_json(r.to_json)
        begin
          row.save!
        rescue ex
          if h = on_err
            v = h.call(r, ex)
            raise v unless v.nil?
          else
            raise ex
          end
        end

        after_save.try &.call(val, row.id.not_nil!)
        success += 1
      rescue ex
        errors << Failure.new(index + 1, row.try &.id.to_s || "", "#{ex.class}: #{ex.message}")
      end
    end
    Log.info { "#{success} of #{records.size} records loaded successfully" }
    Log.warn { errors } unless errors.empty?
  end

  private def decompress_dump(dump)
    temp_dir = File.tempname("rethink", "dump")
    FileUtils.mkdir_p(temp_dir)

    File.open(dump) do |file|
      Compress::Gzip::Reader.open(file) do |gzip|
        Crystar::Reader.open(gzip) do |tar|
          tar.each_entry do |entry|
            path = Path[entry.name]
            next unless path.extension.downcase == ".json"
            File.open(Path[temp_dir, path.basename], mode: "w") do |io|
              IO.copy(entry.io, io)
            end
          end
        end
      end
    end
    temp_dir
  end

  private def load_mod_data(data_dir, clear = true)
    File.open(Path[data_dir, "mod.json"]) do |io|
      PlaceOS::Model::Module.clear if clear
      cb = OnErrorCB.new do |r, ex|
        if ex.message.try &.includes?("should not be associated")
          r.as_h.delete("control_system_id")
          row = PlaceOS::Model::Module.from_trusted_json(r.to_json)
          begin
            row.save!
            nil
          rescue ex
            ex
          end
        else
          ex
        end
      end

      load_data(io, PlaceOS::Model::Module, on_err: cb) { }
    end
  end

  private def load_doorkeeper_data(data_dir, clear = true)
    id_mapping = {} of String => Int64

    File.open(Path[data_dir, "doorkeeper_app.json"]) do |io|
      OAuthToken.clear if clear # clear tokens before to avoid fk violation
      PlaceOS::Model::DoorkeeperApplication.clear if clear
      cb = AfterSaveCB.new do |old_id, new_id|
        id_mapping[old_id.not_nil!] = new_id.as(Int64)
      end

      load_data(io, PlaceOS::Model::DoorkeeperApplication, cb) do |row|
        row.as_h.delete("id").to_s
      end
    end

    File.open(Path[data_dir, "doorkeeper_token.json"]) do |io|
      load_data(io, OAuthToken) do |row|
        h = row.as_h
        h.delete("id")
        id = h.delete("application_id").to_s
        h["application_id"] = JSON::Any.new(id_mapping[id]) if id_mapping.has_key?(id)
        nil
      end
    end
  end

  private def get_file(dump : String)
    uri = URI.parse(dump)
    if uri.scheme || uri.host
      path = Path[uri.path]
      fname = path.basename.empty? ? "rethink_dump.tar.gz" : path.basename
      file_path = File.tempname("rethink_dump_file", fname)
      FileUtils.mkdir_p(file_path)
      file_path = Path[file_path, fname]
      Log.info { "Downloading RethinkDB dump..." }
      ConnectProxy::HTTPClient.get(uri) do |response|
        unless response.success?
          Log.error { "could not found RethinkDB dump. Provided url returned invalid response code #{response.status_code}" }
          exit
        end
        File.write(file_path, response.body_io)
        file_path
      end
    else
      unless File.exists?(uri.path)
        Log.error { "RethinkDB dump file [#{uri.path}] not found" }
        exit
      end
      uri.path
    end
  end

  private record Failure, row : Int32, id : String, reason : String do
    def to_s(io : IO) : Nil
      io << "row #:" << row << ", record id: " << id << ", reason: " << reason << "\n"
    end
  end

  private struct Failures
    def initialize(@table : String)
      @errors = Array(Failure).new
    end

    def to_s(io : IO) : Nil
      io << "Failed to load #{@errors.size} records into table \"#{@table}\"" << "\n"
      @errors.each(&.to_s(io))
    end

    delegate :empty?, :size, :<<, to: @errors
  end

  # :nodoc:
  class OAuthToken < PgORM::Base
    table :oauth_access_tokens
    default_primary_key id : Int64?, autogenerated: true

    attribute resource_owner_id : String
    attribute application_id : Int64
    attribute token : String
    attribute refresh_token : String
    attribute expires_in : Int32
    attribute scopes : String
    attribute previous_refresh_token : String = ""
    attribute created_at : Time = ->{ Time.utc }, converter: PlaceOS::Model::Timestamps::EpochConverter
  end
end

require "./spec_helper"
require "../src/tasks/entities"

module PlaceOS::Tasks
  # The organisation the backfill migration creates for a domain that has none
  def self.backfilled_organisation(authority : Model::Authority) : Model::Organisation
    organisation = Model::Organisation.new(
      name: "#{authority.name} (#{authority.domain})",
      description: "Auto-created from authority #{authority.id} during PPT-526 organisation backfill",
    ).save!
    authority.organisation_id = organisation.id
    authority.save!
    organisation
  end

  def self.owned_zone(organisation : Model::Organisation) : Model::Zone
    zone = Model::Zone.new(name: "zone-#{Random::Secure.hex(4)}", tags: Set{"org"})
    zone.organisation_id = organisation.id
    zone.save!
  end

  def self.organisation_grant(organisation : Model::Organisation) : Model::Grant
    user = Model::Generator.user.save!
    Model::Generator.grant(user, Model::Grant::SCOPE_ORGANISATION, organisation.id.to_s)
  end

  describe Entities do
    describe "create_management_organisation" do
      it "seeds the management partner and attaches an unowned domain to its staff organisation" do
        authority = Model::Generator.authority("https://first.example.com").save!

        organisation = Entities.create_management_organisation(authority)

        organisation.partner_staff.should be_true
        organisation.partner.not_nil!.management.should be_true
        Model::Authority.find!(authority.id.as(String)).organisation_id.should eq organisation.id
      end

      it "is idempotent" do
        authority = Model::Generator.authority("https://first.example.com").save!

        first = Entities.create_management_organisation(authority)
        second = Entities.create_management_organisation(Model::Authority.find!(authority.id.as(String)))

        second.id.should eq first.id
        Model::Partner.where(management: true).count.should eq 1
        Model::Organisation.where(partner_staff: true).count.should eq 1
      end

      it "moves a backfilled estate into the staff organisation" do
        authority = Model::Generator.authority("https://first.example.com").save!
        backfilled = backfilled_organisation(authority)
        zone = owned_zone(backfilled)
        grant = organisation_grant(backfilled).save!

        organisation = Entities.create_management_organisation(authority)

        authority.organisation_id.should eq organisation.id
        Model::Authority.find!(authority.id.as(String)).organisation_id.should eq organisation.id
        Model::Zone.find!(zone.id.as(String)).organisation_id.should eq organisation.id
        Model::Grant.find!(grant.id.not_nil!).scope_id.should eq organisation.id.to_s
        Model::Organisation.find?(backfilled.id.not_nil!).should be_nil
      end

      it "leaves an organisation an operator has changed" do
        authority = Model::Generator.authority("https://first.example.com").save!
        backfilled = backfilled_organisation(authority)
        backfilled.description = "Acme, merged by hand"
        backfilled.save!
        zone = owned_zone(backfilled)

        Entities.create_management_organisation(authority)

        Model::Authority.find!(authority.id.as(String)).organisation_id.should eq backfilled.id
        Model::Zone.find!(zone.id.as(String)).organisation_id.should eq backfilled.id
      end

      it "leaves an organisation that owns other domains" do
        authority = Model::Generator.authority("https://first.example.com").save!
        backfilled = backfilled_organisation(authority)
        other = Model::Generator.authority("https://second.example.com")
        other.organisation_id = backfilled.id
        other.save!

        Entities.create_management_organisation(authority)

        Model::Authority.find!(authority.id.as(String)).organisation_id.should eq backfilled.id
        Model::Organisation.find?(backfilled.id.not_nil!).should_not be_nil
      end
    end
  end
end

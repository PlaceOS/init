require "./spec_helper"
require "../src/tasks/initialization"

module PlaceOS
  module Tasks
    def self.production? : Bool
      true
    end

    def self.start_customer_install(domain : String)
      Initialization.start(
        application_name: "backoffice",
        domain: domain,
        tls: false,
        email: "administrator@example.com",
        username: "Administrator",
        password: "a-test-password-12345",
        auth_host: "auth",
        metrics_route: "monitor",
        backoffice_branch: "master",
        backoffice_commit: "HEAD",
      )
    end

    describe "customer tenancy bootstrap" do
      it "keeps an existing customer's configured domain out of management staff" do
        authority = Model::Generator.authority("customer.example.com").save!
        organisation = Model::Organisation.new(
          name: "Existing customer",
          description: "Auto-created from authority #{authority.id} during PPT-526 organisation backfill",
        ).save!
        authority.organisation_id = organisation.id
        authority.save!

        start_customer_install(authority.domain)

        persisted = Model::Authority.find!(authority.id.as(String))
        persisted.organisation_id.should eq organisation.id
        persisted.organisation.not_nil!.partner_staff.should be_false
        Model::Partner.where(management: true).count.should eq 0
      end

      it "creates an ordinary organisation for a fresh default customer install" do
        start_customer_install("fresh-customer.example.com")

        authority = Model::Authority.find_by_domain("fresh-customer.example.com").not_nil!
        organisation = authority.organisation.not_nil!
        organisation.partner_staff.should be_false
        organisation.partner_id.should be_nil
        Model::Partner.where(management: true).count.should eq 0
      end
    end
  end
end

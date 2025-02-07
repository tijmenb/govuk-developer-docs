RSpec.describe AppDocs::App do
  before :each do
    allow(AppDocs).to receive(:pages) do
      applications.map(&:stringify_keys).map { |app_data| AppDocs::App.new(app_data) }
    end
  end

  let(:applications) do
    [
      { github_repo_name: "whitehall", production_hosted_on: "aws" },
      { github_repo_name: "asset-manager", production_hosted_on: "aws", consume_docs_folder: false },
      { github_repo_name: "content-store", production_hosted_on: "aws", consume_docs_folder: false },
      { github_repo_name: "govuk-frontend", production_hosted_on: "aws", consume_docs_folder: false },
      { github_repo_name: "collections-publisher", production_hosted_on: "carrenza", consume_docs_folder: false },
      { github_repo_name: "second-app-on-carrenza", production_hosted_on: "carrenza", consume_docs_folder: false },
      { github_repo_name: "app-on-heroku", production_hosted_on: "heroku", consume_docs_folder: false },
      { github_repo_name: "app-on-paas", production_hosted_on: "paas" },
      { github_repo_name: "some-retired-application", consume_docs_folder: false },
    ]
  end

  describe "production_url" do
    it "has a good default" do
      app = AppDocs::App.new("type" => "Publishing app", "github_repo_name" => "my-app")

      expect(app.production_url).to eql("https://my-app.publishing.service.gov.uk")
    end

    it "allows override" do
      app = AppDocs::App.new("type" => "Publishing app", "production_url" => "something else")

      expect(app.production_url).to eql("something else")
    end
  end

  describe "hosters_descending" do
    it "should return hosters in descending order of repo count" do
      expect(AppDocs.hosters_descending.keys).to eq(%w[
        aws
        carrenza
        heroku
        paas
        none
        ukcloud
      ])
    end
  end

  describe "apps_on_host" do
    it "should return apps hosted on the named host" do
      paas_app = AppDocs.apps_on_host("paas").first
      expect(paas_app).to be_an(AppDocs::App)
      expect(paas_app.app_name).to eq("app-on-paas")
    end

    it "should return all apps in production" do
      production_apps_count = applications.count { |app| app[:production_hosted_on].present? }
      apps_by_host = AppDocs::HOSTERS.map { |key, _val| AppDocs.apps_on_host(key) }.flatten
      expect(apps_by_host.count).to eq(production_apps_count)
    end

    it "should return apps in alphabetical order" do
      apps_on_aws = AppDocs.apps_on_host("aws")
      expect(apps_on_aws.map(&:app_name)).to eq(%w[
        asset-manager
        content-store
        govuk-frontend
        whitehall
      ])
    end
  end

  describe "aws_puppet_class" do
    before do
      app_data = {
        "calculators_frontend" => {
          "apps" => %w[
            calculators
            finder-frontend
            licencefinder
            smartanswers
          ],
        },
      }
      allow(AppDocs).to receive(:aws_machines).and_return(app_data)
    end

    it "should find puppet class via github repo name if neither app name nor puppet name provided" do
      expect(AppDocs::App.new("github_repo_name" => "calculators").aws_puppet_class).to eq("calculators_frontend")
    end

    it "should find puppet class via app name" do
      expect(AppDocs::App.new("app_name" => "calculators").aws_puppet_class).to eq("calculators_frontend")
    end

    it "should find puppet class via puppet name" do
      expect(AppDocs::App.new("puppet_name" => "smartanswers", "github_repo_name" => "foo").aws_puppet_class).to eq("calculators_frontend")
    end

    it "should return error message if no puppet class found" do
      expect(AppDocs::App.new("github_repo_name" => "foo").aws_puppet_class)
        .to eq("Unknown - have you configured and merged your app in govuk-puppet/hieradata_aws/common.yaml")
    end
  end

  describe "apps_with_docs" do
    it "should return apps alphabetically, omitting those that have opted out" do
      expect(AppDocs.apps_with_docs.map(&:app_name)).to eq(%w[app-on-paas whitehall])
    end
  end

  describe "dashboard_url" do
    let(:production_hosted_on) { nil }
    let(:app) do
      described_class.new(
        "type" => "Publishing app",
        "github_repo_name" => "my-app",
        "production_hosted_on" => production_hosted_on,
      )
    end
    subject(:dashboard_url) { app.dashboard_url }

    describe "hosted on AWS" do
      let(:production_hosted_on) { "aws" }
      it { is_expected.to eql("https://grafana.production.govuk.digital/dashboard/file/my-app.json") }
    end

    describe "hosted on Carrenza" do
      let(:production_hosted_on) { "carrenza" }
      it { is_expected.to eql("https://grafana.publishing.service.gov.uk/dashboard/file/my-app.json") }
    end
  end

  describe "rake_task_url" do
    let(:production_hosted_on) { nil }
    let(:environment) { nil }
    let(:rake_task) { "" }
    let(:app) do
      described_class.new(
        "github_repo_name" => "content-publisher",
        "machine_class" => "backend",
        "production_hosted_on" => production_hosted_on,
      )
    end
    subject(:dashboard_url) { app.rake_task_url(environment, rake_task) }

    describe "hosted on AWS and environment is production" do
      let(:production_hosted_on) { "aws" }
      let(:environment) { "production" }

      it { is_expected.to eql("https://deploy.blue.production.govuk.digital/job/run-rake-task/parambuild/?TARGET_APPLICATION=content-publisher&MACHINE_CLASS=backend&RAKE_TASK=") }

      describe "with a Rake task" do
        let(:rake_task) { "task" }
        it { is_expected.to eql("https://deploy.blue.production.govuk.digital/job/run-rake-task/parambuild/?TARGET_APPLICATION=content-publisher&MACHINE_CLASS=backend&RAKE_TASK=task") }
      end
    end

    describe "hosted on AWS and environment is integration" do
      let(:production_hosted_on) { "aws" }
      let(:environment) { "integration" }

      it { is_expected.to eql("https://deploy.integration.publishing.service.gov.uk/job/run-rake-task/parambuild/?TARGET_APPLICATION=content-publisher&MACHINE_CLASS=backend&RAKE_TASK=") }

      describe "with a Rake task" do
        let(:rake_task) { "task" }
        it { is_expected.to eql("https://deploy.integration.publishing.service.gov.uk/job/run-rake-task/parambuild/?TARGET_APPLICATION=content-publisher&MACHINE_CLASS=backend&RAKE_TASK=task") }
      end
    end

    describe "hosted on Carrenza and environment is production" do
      let(:production_hosted_on) { "carrenza" }
      let(:environment) { "production" }

      it { is_expected.to eql("https://deploy.publishing.service.gov.uk/job/run-rake-task/parambuild/?TARGET_APPLICATION=content-publisher&MACHINE_CLASS=backend&RAKE_TASK=") }

      describe "with a Rake task" do
        let(:rake_task) { "task" }
        it { is_expected.to eql("https://deploy.publishing.service.gov.uk/job/run-rake-task/parambuild/?TARGET_APPLICATION=content-publisher&MACHINE_CLASS=backend&RAKE_TASK=task") }
      end
    end

    describe "hosted on Carrenza and environment is integration" do
      let(:production_hosted_on) { "carrenza" }
      let(:environment) { "integration" }

      it { is_expected.to eql("https://deploy.integration.publishing.service.gov.uk/job/run-rake-task/parambuild/?TARGET_APPLICATION=content-publisher&MACHINE_CLASS=backend&RAKE_TASK=") }

      describe "with a Rake task" do
        let(:rake_task) { "task" }
        it { is_expected.to eql("https://deploy.integration.publishing.service.gov.uk/job/run-rake-task/parambuild/?TARGET_APPLICATION=content-publisher&MACHINE_CLASS=backend&RAKE_TASK=task") }
      end
    end
  end

  describe "consume_docs_folder" do
    it "should return true if unspecified" do
      app = AppDocs::App.new({})
      expect(app.consume_docs_folder).to eq(true)
    end

    it "should return the consume_docs_folder property if supplied" do
      app = AppDocs::App.new({ "consume_docs_folder" => false })
      expect(app.consume_docs_folder).to eq(false)
    end

    it "should return false if the repo is private" do
      app = AppDocs::App.new({ "private_repo" => true, "consume_docs_folder" => true })
      expect(app.consume_docs_folder).to eq(false)
    end
  end
end

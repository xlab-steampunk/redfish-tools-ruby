# frozen_string_literal: true

require "base64"
require "openssl"
require "webrick"
require "webrick/https"

require "redfish_tools/servlet"

module RedfishTools
  class Server < WEBrick::HTTPServer
    def initialize(datastore, username, password, config = {})
      super(config)

      @datastore = datastore
      root = datastore.get("/redfish/v1").body
      @login_path = root.dig("Links", "Sessions", "@odata.id")&.chomp("/")
      @username = username
      @password = password

      mount("/", Servlet)
    end

    attr_reader :datastore, :login_path, :username, :password

    def basic_auth_header
      @basic_auth_header ||= "Basic " +
        Base64.strict_encode64("#{username}:#{password}")
    end

    def actions
      # Hash of action_id => system_id
      @actions ||= load_all_actions
    end

    def systems
      @systems ||= load_all_system_ids
    end

    private

    def load_all_system_ids
      systems_id = datastore.get("/redfish/v1").body["Systems"]["@odata.id"]
      datastore.get(systems_id).body["Members"].map { |l| l["@odata.id"] }
    end

    def load_all_actions
      load_all_system_actions.merge(load_update_actions)
    end

    def load_all_system_actions
      systems_id = datastore.get("/redfish/v1").body["Systems"]["@odata.id"]
      datastore.get(systems_id).body["Members"].reduce({}) do |acc, link|
        acc.merge(load_system_actions(link["@odata.id"]))
      end
    end

    def load_system_actions(id)
      actions = datastore.get(id).body.dig("Actions") || {}
      actions.each_with_object({}) do |(name, data), acc|
        acc[data["target"]] = { name: name, id: id }
      end
    end

    def load_update_actions
      update_service_id = datastore.get("/redfish/v1").body.dig(
        "UpdateService", "@odata.id",
      )
      return {} if update_service_id.nil?

      actions = datastore.get(update_service_id).body["Actions"] || {}
      actions.each_with_object({}) do |(name, data), acc|
        acc[data["target"]] = { name: name, id: update_service_id }
      end
    end
  end
end

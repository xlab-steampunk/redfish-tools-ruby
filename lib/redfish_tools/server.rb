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

    def system_actions
      # Hash of action_id => system_id
      @system_actions ||= load_all_system_actions
    end

    private

    def load_all_system_actions
      systems_id = datastore.get("/redfish/v1").body["Systems"]["@odata.id"]
      datastore.get(systems_id).body["Members"].reduce({}) do |acc, link|
        acc.merge(load_system_actions(link["@odata.id"]))
      end
    end

    def load_system_actions(id)
      actions = datastore.get(id).body.dig("Actions") || {}
      actions.each_with_object({}) do |(name, data), acc|
        acc[data["target"]] = { name: name, system_id: id }
      end
    end
  end
end

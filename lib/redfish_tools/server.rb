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
  end
end

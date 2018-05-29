# frozen_string_literal: true

require "openssl"
require "webrick"
require "webrick/https"

require "redfish_tools/servlet"

module RedfishTools
  class Server < WEBrick::HTTPServer
    def initialize(datastore, config = {})
      super(config)

      root = JSON.parse(datastore.get("/redfish/v1").body)
      login_path = root.dig("Links", "Sessions", "@odata.id")
      mount("/", Servlet, datastore, login_path)
    end
  end
end

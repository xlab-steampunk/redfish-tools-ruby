# frozen_string_literal: true

require "redfish_client"
require "redfish_tools/recorder"

module RedfishTools
  class Cli
    class Record
      def initialize(service, path, username, password)
        @service = service
        @path = path
        @username = username
        @password = password
      end

      def run
        client = RedfishClient.new(@service, verify: false)
        client.login(@username, @password)
        Recorder.new(client, @path).record
      end
    end
  end
end

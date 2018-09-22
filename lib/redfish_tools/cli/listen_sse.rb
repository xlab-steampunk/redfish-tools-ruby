# frozen_string_literal: true

require "redfish_tools/sse_client"

module RedfishTools
  class Cli
    class ListenSse
      def initialize(address, options)
        @address = address
        @options = options
      end

      def run
        sse = RedfishTools::SseClient.new(@address)
        trap("INT") { exit }
        sse.start
      end
    end
  end
end

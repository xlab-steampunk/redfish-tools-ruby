# frozen_string_literal: true

require "redfish_tools/sse_server"

module RedfishTools
  class Cli
    class ServeSse
      def initialize(source, options)
        @source = source
        @options = options
      end

      def run
        sse = RedfishTools::SseServer.new(
          @source, @options[:bind], @options[:port]
        )
        trap("INT") { exit }
        sse.start
      end
    end
  end
end

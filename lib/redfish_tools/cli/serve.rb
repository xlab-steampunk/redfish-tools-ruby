# frozen_string_literal: true

require "redfish_tools/datastore"
require "redfish_tools/server"

module RedfishTools
  class Cli
    class Serve
      def initialize(path, options)
        @path = path
        @options = options
      end

      def run
        datastore = RedfishTools::DataStore.new(@path)
        server = RedfishTools::Server.new(datastore,
                                          Port: @options[:port],
                                          BindAddress: @options[:bind])
        trap("INT") { server.shutdown }
        server.start
      end
    end
  end
end

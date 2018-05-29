# frozen_string_literal: true

require "cri"

require "redfish_tools/datastore"
require "redfish_tools/server"

module RedfishTools
  module Cli
    class Serve < Cri::CommandRunner
      def run
        datastore = RedfishTools::DataStore.new(arguments[0])
        server = RedfishTools::Server.new(datastore, Port: options[:port])
        trap("INT") { server.shutdown }
        server.start
      end
    end
  end
end

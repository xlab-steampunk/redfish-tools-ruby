# frozen_string_literal: true

require "thor"

module RedfishTools
  class Cli < Thor
    def self.start(args = ARGV)
      if HELP_MAPPINGS.any? { |flag| args.include?(flag) }
        args = ["--help", args.first]
      end
      super(args)
    end

    desc "serve [OPTIONS] PATH", "serve mock from PATH"
    option :port,
           desc: "port that should be used to serve the mock",
           default: 8000,
           type: :numeric
    option :bind,
           desc: "address that server should bind to",
           default: "127.0.0.1"
    def serve(path)
      require "redfish_tools/cli/serve"
      Serve.new(path, options).run
    end
  end
end

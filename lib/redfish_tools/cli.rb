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

    def self.exit_on_failure?
      true
    end

    desc "serve [OPTIONS] PATH", "serve mock from PATH"
    option :port,
           desc: "port that should be used to serve the mock",
           default: 8000,
           type: :numeric
    option :bind,
           desc: "address that server should bind to",
           default: "127.0.0.1"
    option :ssl,
           desc: "use SSL",
           default: false,
           type: :boolean
    option :user,
           desc: "username to use"
    option :pass,
           desc: "password to use"
    def serve(path)
      user = options[:user]
      pass = options[:pass]
      raise Thor::Error, "Missing password" if user && pass.nil?
      raise Thor::Error, "Missing username" if user.nil? && pass

      require "redfish_tools/cli/serve"
      Serve.new(path, options).run
    rescue StandardError => e
      raise Thor::Error, e.to_s
    end
  end
end

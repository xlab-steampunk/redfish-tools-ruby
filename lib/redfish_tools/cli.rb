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
      raise "Missing password" if user && pass.nil?
      raise "Missing username" if user.nil? && pass

      require "redfish_tools/cli/serve"
      Serve.new(path, options).run
    rescue StandardError => e
      raise Thor::Error, e.to_s
    end

    desc "record SERVICE PATH", "create recording of SERVICE in PATH"
    long_desc <<-LONGDESC
      Record a Redfish service content into set of static files and store them
      on disk. Sample record call:

        $ . password_file
        $ redfish record https://my.redfish.api:8443 output folder

      Before running this command, make sure REDFISH_USERNAME and
      REDFISH_PASSWORD environment variables are set. The recommended way of
      setting them is by writing the assignments down into shell script that
      can be then sourced as shown in example.
    LONGDESC
    def record(service, path)
      username = ENV["REDFISH_USERNAME"]
      password = ENV["REDFISH_PASSWORD"]
      raise "Missing username" if username.nil?
      raise "Missing password" if password.nil?

      require "redfish_tools/cli/record"
      Record.new(service, path, username, password).run
    rescue StandardError => e
      raise Thor::Error, e.to_s
    end
  end
end

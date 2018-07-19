# frozen_string_literal: true

require "json"
require "set"
require "webrick"

module RedfishTools
  class Servlet < WEBrick::HTTPServlet::AbstractServlet
    BAD_HEADERS = Set.new(["connection", "content-length", "keep-alive"])
    DEFAULT_HEADERS = {
      "content-type" => "application/json"
    }.freeze

    def initialize(server, datastore, login_path)
      super(server)
      @datastore = datastore
      @login_path = login_path.chomp("/")
    end

    def do_GET(request, response)
      return response.status = 401 unless authorized?(request)

      resource = @datastore.get(request.path)
      response.body = resource.body.to_json
      set_headers(response, resource.headers)
      response.status = response.body ? 200 : 404
    end

    def do_POST(request, response)
      return response.status = 401 unless authorized?(request)

      if login_path?(request.path)
        login(request, response)
      else
        response.status = 501
      end
    end

    def do_PUT(_request, response)
      response.status = 501
    end

    def do_PATCH(_request, response)
      response.status = 501
    end

    def do_DELETE(_request, response)
      response.status = 501
    end

    private

    def login_path?(path)
      @login_path == path.chomp("/")
    end

    def login(request, response)
      credentials = JSON.parse(request.body)
      response.body = {
        "Name"        => "User Session",
        "Description" => "User Session",
        "UserName"    => credentials["UserName"]
      }.to_json
      set_headers(response, DEFAULT_HEADERS.merge("X-Auth-Token" => "dummy"))
      response.status = 201
    end

    def authorized?(_request)
      # TODO(tadeboro): Add checks as per Redfish standard
      true
    end

    def set_headers(response, headers)
      headers ||= DEFAULT_HEADERS
      headers.each do |k, v|
        response[k] = v unless BAD_HEADERS.member?(k.downcase)
      end
    end
  end
end

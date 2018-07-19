# frozen_string_literal: true

require "forwardable"
require "json"
require "securerandom"
require "set"
require "webrick"

module RedfishTools
  class Servlet < WEBrick::HTTPServlet::AbstractServlet
    extend Forwardable

    def_delegators :@server,
                   :datastore, :login_path, :username, :password,
                   :basic_auth_header

    BAD_HEADERS = Set.new(["connection", "content-length", "keep-alive"])
    DEFAULT_HEADERS = {
      "content-type" => "application/json"
    }.freeze

    def service(request, response)
      return response.status = 401 unless authorized?(request)
      return response.status = 404 unless datastore.get(request.path).body

      super
    end

    def do_GET(request, response)
      item = datastore.get(request.path)
      response.status = 200
      set_headers(response, item.headers)
      response.body = item.body.to_json
    end

    def do_POST(request, response)
      item = datastore.get(request.path)
      return response.status = 405 unless item.body["Members"]

      data = JSON.parse(request.body)
      item_n = login_path?(request) ? login(item, data) : new_item(item, data)
      return response.status = 400 unless item_n.body

      response.status = 201
      set_headers(response, item_n.headers)
      response.body = item_n.body.to_json
    rescue JSON::ParserError
      response.status = 400
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

    def login_path?(request)
      login_path == request.path.chomp("/")
    end

    def login(item, data)
      user = data["UserName"]
      pass = data["Password"]
      return nil unless username == user && password == pass

      res = new_item(item,
                     "@odata.type" => "#Session.v1_1_0.Session",
                     "UserName"    => user,
                     "Password"    => nil)
      res.headers = DEFAULT_HEADERS.merge("X-Auth-Token" => res.body["Id"])
      res
    end

    def new_item(item, data)
      id = SecureRandom.uuid
      oid = item.id.chomp("/") + "/" + id
      item.body["Members@odata.count"] += 1
      item.body["Members"].push("@odata.id" => oid)

      base = { "@odata.id" => oid, "Id" => id, "Name" => id }
      datastore.set(id, base.merge(data))
    end

    def authorized?(request)
      username.nil? || # Server has no credentials set
        always_allow?(request.path) || # Non-protected endpoints
        authorized_basic?(request) ||
        authorized_session?(request) ||
        (request.request_method == "POST" && login_path?(request))
    end

    def always_allow?(path)
      [
        "/redfish",
        "/redfish/v1",
        "/redfish/v1/$metadata",
        "/redfish/v1/odata"
      ].include?(path.chomp("/"))
    end

    def authorized_basic?(request)
      request["authorization"] == basic_auth_header
    end

    def authorized_session?(request)
      return false if login_path.nil? || request["X-Auth-Token"].nil?
      remove_stale_sessions
      datastore.get(login_path).body["Members"].any? do |session|
        session["@odata.id"].index(request["X-Auth-Token"])
      end
    end

    def remove_stale_sessions
      # TODO(tadeboro): implement session expiration
      nil
    end

    def set_headers(response, headers)
      headers ||= DEFAULT_HEADERS
      headers.each do |k, v|
        response[k] = v unless BAD_HEADERS.member?(k.downcase)
      end
    end
  end
end

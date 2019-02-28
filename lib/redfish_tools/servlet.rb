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
      return response.status = 404 unless item.body
      return response.status = 405 if item.body["Members"].nil?

      data = JSON.parse(request.body)
      if login_path?(request.path)
        body, headers, status = login(item, data)
      else
        body, headers, status = new_item(item, data)
      end

      response.status = status
      set_headers(response, headers)
      response.body = body.to_json
    rescue JSON::ParserError
      response.status = 400
      set_headers(response)
      response.body = error_body("Invalid JSON").to_json
    end

    def do_PUT(_request, response)
      response.status = 501
    end

    def do_PATCH(_request, response)
      response.status = 501
    end

    def do_DELETE(request, response)
      delete_item(datastore.get(request.path))
      response.status = 204
    end

    private

    def error_body(msg)
      { "error" => { "message" => msg } }
    end

    def login_path?(path)
      login_path == path.chomp("/")
    end

    def login(item, data)
      user = data["UserName"]
      unless username == user && password == data["Password"]
        return error_body("Invalid username/password"), nil, 400
      end

      body, _, status = new_item(item,
                                 "@odata.type" => "#Session.v1_1_0.Session",
                                 "UserName"    => user,
                                 "Password"    => nil)
      [body, DEFAULT_HEADERS.merge("X-Auth-Token" => body["Id"]), status]
    end

    def new_item(item, data)
      id = SecureRandom.uuid
      oid = item.id.chomp("/") + "/" + id
      item.body["Members@odata.count"] += 1
      item.body["Members"].push("@odata.id" => oid)

      base = { "@odata.id" => oid, "Id" => id, "Name" => id }
      new_item = datastore.set(oid, base.merge(data), parent: item)
      [new_item.body, nil, 201]
    end

    def delete_item(item)
      if item.parent
        item.parent.body["Members@odata.count"] -= 1
        item.parent.body["Members"].delete_if do |m|
          m["@odata.id"] == item.id
        end
      end
      datastore.set(item.id, nil)
    end

    def authorized?(request)
      username.nil? || # Server has no credentials set
        always_allow?(request.path) || # Non-protected endpoints
        authorized_basic?(request) ||
        authorized_session?(request) ||
        (request.request_method == "POST" && login_path?(request.path))
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

    def set_headers(response, headers = nil)
      headers ||= DEFAULT_HEADERS
      headers.each do |k, v|
        response[k] = v unless BAD_HEADERS.member?(k.downcase)
      end
    end
  end
end

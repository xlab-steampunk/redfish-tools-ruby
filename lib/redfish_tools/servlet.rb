# frozen_string_literal: true

require "forwardable"
require "json"
require "securerandom"
require "set"
require "webrick"
require "redfish_tools/utils"
require "redfish_tools/exceptions"

module RedfishTools
  class Servlet < WEBrick::HTTPServlet::AbstractServlet
    extend Forwardable

    def_delegators :@server,
                   :datastore, :login_path, :username, :password,
                   :basic_auth_header, :actions, :systems

    BAD_HEADERS = Set.new(["connection", "content-length", "keep-alive"])
    DEFAULT_HEADERS = {
      "content-type" => "application/json"
    }.freeze
    TRANSITIONS = {
      "PoweringOn"  => {}.freeze,
      "On"          => {
        "GracefulShutdown" => "Off",
        "ForceOff"         => "Off",
        "PushPowerButton"  => "Off",
        "Nmi"              => "Off",
        "GracefulRestart"  => "On",
        "ForceRestart"     => "On",
        "PowerCycle"       => "On",
      }.freeze,
      "PoweringOff" => {}.freeze,
      "Off"         => {
        "On"              => "On",
        "ForceOn"         => "On",
        "PushPowerButton" => "On",
      }.freeze,
    }.freeze
    TASK_TRANSITIONS = {
      "New"       => "Starting",
      "Starting"  => "Running",
      "Running"   => "Completed",
      "Completed" => "Completed",
    }

    def service(request, response)
      return response.status = 401 unless authorized?(request)

      super
    end

    def do_GET(request, response)
      return response.status = 404 unless datastore.get(request.path).body

      item = datastore.get(request.path)
      response.status = 200

      if request.path.chomp("/").end_with?("monitor") && item.body["TaskState"]
        item.body["TaskState"] = TASK_TRANSITIONS[item.body["TaskState"]]
        response.status = 202
        if item.body["TaskState"] == "Completed"
          response.status = 200
          item.body["EndTime"] = Time.now.utc.iso8601
        end
      end

      set_headers(response, item.headers)
      response.body = item.body.to_json
    end

    def do_POST(request, response)
      action = actions[request.path]
      item = datastore.get(request.path)
      return response.status = 404 unless action || item.body
      return response.status = 405 if action.nil? && item.body["Members"].nil?

      data = JSON.parse(request.body)
      if action
        body, headers, status = execute_action(action, data)
      elsif login_path?(request.path)
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

    def do_PATCH(request, response)
      system = datastore.get(request.path)
      return response.status = 404 unless system.body
      system.body = Utils.combine_hashes(system.body, JSON.parse(request.body))
      response.status = 200
    rescue Exceptions::MergeConflict => error
      response.status = 405
      set_headers(response)
      response.body = error_body(error).to_json
    end

    def do_DELETE(request, response)
      item = datastore.get(request.path)
      return response.status = 404 unless item.body

      delete_item(item)
      response.status = 204
    end

    private

    def error_body(msg)
      { "error" => { "message" => msg } }
    end

    def execute_action(action, data)
      resource = datastore.get(action[:id]).body
      case action[:name]
      when "#ComputerSystem.Reset"
        execute_computer_system_reset(resource, data)
      when "#UpdateService.SimpleUpdate"
        execute_update_service_simple_update(resource, data)
      end
    end

    def execute_computer_system_reset(system, data)
      action = system["Actions"]["#ComputerSystem.Reset"]
      reset = data["ResetType"]

      # TODO(@tadeboro): Handle ActionInfo case also.
      unless action["ResetType@Redfish.AllowableValues"].include?(reset)
        return error_body("Invalid reset type"), nil, 400
      end

      unless TRANSITIONS[system["PowerState"]].key?(reset)
        return error_body("Invalid reset type for curent state"), nil, 400
      end

      # Simulate reset action
      system["PowerState"] = TRANSITIONS[system["PowerState"]][reset]

      [error_body("Success"), nil, 200]
    end

    def execute_update_service_simple_update(service, data)
      action = service["Actions"]["#UpdateService.SimpleUpdate"]
      proto = data["TransferProtocol"]
      targets = data["Targets"] || []

      # TODO(@tadeboro): Handle ActionInfo case also.
      unless action["TransferProtocol@Redfish.AllowableValues"].include?(proto)
        return error_body("Invalid transfer protocol value"), nil, 400
      end

      unless (targets - systems).empty?
        return error_body("Invalid targets: #{targets - systems}"), nil, 400
      end

      task_service_id = datastore.get("/redfish/v1").body["Tasks"]["@odata.id"]
      task_col_id = datastore.get(task_service_id).body["Tasks"]["@odata.id"]

      body, _, _ = new_item(datastore.get(task_col_id), {
        "TaskState" => "New",
        "StartTime" => Time.new.utc.iso8601,
      })

      task_monitor_path = body["@odata.id"] + "/monitor"
      headers = DEFAULT_HEADERS.merge("location" => task_monitor_path)

      body["TaskMonitor"] = task_monitor_path
      datastore.set(task_monitor_path, body, headers: headers)

      [body, headers, 202]
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

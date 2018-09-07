# frozen_string_literal: true

require "json"

module RedfishTools
  class DataStore
    Resource = Struct.new(:id, :body, :headers, :time, :parent)

    def initialize(base_path)
      @base_path = File.expand_path(base_path)
      @overlay = {}

      root_file = File.join(@base_path, "redfish", "v1", "index.json")
      raise "Invalid recording folder" unless File.file?(root_file)
    end

    def get(id)
      id = id.chomp("/")
      @overlay[id] = @overlay.fetch(id, load_resource(id))
    end

    def set(id, body, headers: nil, time: nil, parent: nil)
      @overlay[id] = Resource.new(id, body, headers, time, parent)
    end

    private

    def load_resource(id)
      Resource.new(id, load_body(id), load_headers(id), load_time(id))
    end

    def load_body(id)
      load_json(File.join(@base_path, id, "index.json"))
    end

    def load_headers(id)
      headers = load_json(File.join(@base_path, id, "headers.json"))
      headers && headers["GET"]
    end

    def load_time(id)
      times = load_json(File.join(@base_path, id, "time.json"))
      times && times["GET_Time"]&.to_f
    end

    def load_json(path)
      File.readable?(path) ? JSON.parse(File.read(path)) : nil
    end
  end
end

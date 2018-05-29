# frozen_string_literal: true

require "json"

module RedfishTools
  class DataStore
    Resource = Struct.new(:id, :body, :headers, :time)

    def initialize(base_path)
      # TODO(tadeboro): check for folder and determine mode of operation
      @base_path = File.expand_path(base_path)
      @overlay = {}
    end

    def get(id)
      id = id.chomp("/")
      @overlay[id] || load_resource(id)
    end

    def set(id, body, headers: nil, time: nil)
      @overlay[id] = Resource.new(id, body, headers, time)
    end

    private

    def load_resource(id)
      Resource.new(id, load_body(id), load_headers(id), load_time(id))
    end

    def load_body(id)
      load(File.join(@base_path, id, "index.json"))
    end

    def load_headers(id)
      load_json(File.join(@base_path, id, "headers.json"))["GET"]
    end

    def load_time(id)
      load_json(File.join(@base_path, id, "time.json"))["GET_Time"].to_f
    end

    def load(path)
      File.readable?(path) ? File.read(path) : nil
    end

    def load_json(path)
      content = load(path)
      content ? JSON.parse(content) : {}
    end
  end
end

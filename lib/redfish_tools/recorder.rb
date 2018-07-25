# frozen_string_literal: true

require "fileutils"
require "json"
require "set"

module RedfishTools
  # Recorder represents entry point into mock creation process.
  class Recorder
    def initialize(client, disk_path)
      raise "Directory '#{disk_path}' exists" if File.directory?(disk_path)

      @path = disk_path
      @client = client
    end

    def record
      visited = Set.new
      batch = Set.new([@client["@odata.id"]])

      until batch.empty?
        visited.merge(batch)
        batch = process_oid_batch(batch, visited)
      end
    end

    private

    def process_oid_batch(batch, visited)
      next_batch = Set.new
      batch.each do |oid|
        puts("  Recording #{oid}")
        next_batch.merge(process_oid(oid).subtract(visited))
      end
      next_batch
    end

    def process_oid(oid)
      start = Time.now
      resource = @client.find(oid)
      duration = Time.now - start
      return Set.new unless resource

      persist_to_disk(oid, resource.raw, resource.headers, duration)
      extract_oids(resource.raw)
    end

    def persist_to_disk(oid, body, headers, duration)
      resource_path = File.join(@path, oid)
      index_path = File.join(resource_path, "index.json")
      headers_path = File.join(resource_path, "headers.json")
      time_path = File.join(resource_path, "time.json")

      FileUtils.mkdir_p(resource_path)
      write_json(index_path, sanitize(body))
      write_json(headers_path, "GET" => headers)
      write_json(time_path, "GET_Time" => duration.to_s)
    end

    def sanitize(data)
      case data
      when Hash then sanitize_hash(data)
      when Array then data.map { |v| sanitize(v) }
      else data
      end
    end

    def sanitize_hash(data)
      keys = %w[serialnumber uuid durablename]
      data.reduce({}) do |acc, (k, v)|
        v = keys.include?(k.downcase) ? "REMOVED_FROM_MOCK" : sanitize(v)
        acc.merge!(k => v)
      end
    end

    def write_json(path, data)
      write(path, data.to_json)
    end

    def write(path, data)
      File.open(path, "w") { |f| f.write(data) }
    end

    def extract_oids_from_hash(data)
      ids = Set.new
      ids.add(data["@odata.id"]) if data["@odata.id"]
      data.values.reduce(ids) { |a, v| a.merge(extract_oids(v)) }
    end

    def extract_oids(data)
      case data
      when Hash then extract_oids_from_hash(data)
      when Array then data.reduce(Set.new) { |a, v| a.merge(extract_oids(v)) }
      else Set.new
      end
    end
  end
end

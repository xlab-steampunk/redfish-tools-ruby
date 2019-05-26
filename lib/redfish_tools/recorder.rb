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
      resource, duration = fetch_resource(oid)
      if resource
        persist_to_disk(oid, resource.raw, resource.headers, duration)
        extract_oids(resource.raw)
      else
        puts("!!!! FAILED TO FETCH #{oid} !!!!")
        Set.new
      end
    end

    def fetch_resource(oid)
      3.times do
        begin
          start = Time.now
          resource = @client.find(oid)
          duration = Time.now - start
          return [resource, duration] if resource
        rescue JSON::ParserError => e
          return [nil, nil]
        end

        sleep(2)
      end
      [nil, nil]
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

    def extract_oids(data)
      result = Set.new

      case data
      when Hash then data.values.each { |v| result.merge(extract_oids(v)) }
      when Array then data.each { |v| result.merge(extract_oids(v)) }
      when String then result.add(data) if path?(data)
      end

      result
    end

    def path?(data)
      /^\/redfish\/v1\/[^# ]*$/.match(data)
    end
  end
end

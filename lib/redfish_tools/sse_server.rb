# frozen_string_literal: true

require "date"
require "json"
require "securerandom"
require "socket"

module RedfishTools
  class SseServer
    HEADERS = "HTTP/1.1 200 OK\r\n"\
              "Content-Type: text/event-stream\r\n"\
              "\r\n"

    def initialize(source, address, port)
      @events = load_events(source)
      @server = TCPServer.open(address, port)
    end

    def start
      loop { Thread.start(@server.accept) { |client| handle_client(client) } }
    end

    private

    def load_events(source)
      JSON.parse(File.read(source))
    end

    def handle_client(socket)
      socket.print(HEADERS)
      id = 0
      loop do
        event = @events.sample
        make_events_unique(event["Events"])
        socket.print("id: #{id}\ndata: #{event.to_json}\n\n")
        sleep(rand(1..60))
        id += 1
      end
    ensure
      socket.close
    end

    def make_events_unique(events)
      events.each do |event|
        event["EventTimestamp"] = Time.now.utc.to_s
        event["EventId"] = SecureRandom.uuid
      end
    end
  end
end

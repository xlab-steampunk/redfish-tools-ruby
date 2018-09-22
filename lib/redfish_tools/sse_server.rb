# frozen_string_literal: true

require "date"
require "json"
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
        event["Events"][0]["EventTimestamp"] = DateTime.now.to_s
        socket.print("id: #{id}\ndata: #{event.to_json}\n\n")
        sleep(rand(1..10))
        id += 1
      end
    ensure
      socket.close
    end
  end
end

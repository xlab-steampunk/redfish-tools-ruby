# frozen_string_literal: true

require "json"

require "server_sent_events"

module RedfishTools
  class SseClient
    def initialize(address)
      @address = address
    end

    def start
      ServerSentEvents.listen(@address) do |event|
        puts JSON.pretty_generate("id"   => event.id,
                                  "data" => JSON.parse(event.data))
      end
    end
  end
end

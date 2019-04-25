module RedfishTools
  module Exceptions
    class RedfishServerError < StandardError; end

    class MergeConflict < RedfishServerError; end
  end
end
require "redfish_tools/exceptions"

module RedfishTools
  module Utils
    def self.combine_hashes(original, b, path: nil)
      path ||= []
      a = original.clone
      b.each {|key, value|
        if a.include?(key)
          if (a[key].is_a? Hash) && (b[key].is_a? Hash)
            a[key] = combine_hashes(a[key], b[key], path: path + [key.to_s])
          elsif a[key].is_a? b[key].class
            a[key] = b[key]
          else
            raise Exceptions::MergeConflict, "Conflict at '%s'" % (path + [key.to_s]).join(".")
          end
        else
          raise Exceptions::MergeConflict, "Key '%s' does not exists in source hash" % (path + [key.to_s]).join(".")
        end
      }
      a
    end
  end
end
module PACKMAN
  class OS
    def self.type
      @@type
    end

    def self.scan
      res = `uname`
      case res
      when /^Darwin */
        @@type = :Darwin
      when /^Linux */
        @@type = :Linux
      else
        report_error "Unknown OS type \"#{res}\"!"
      end
    end

    def self.shared_library_suffix
      case type
      when :Darwin
        'dylib'
      when :Linux
        'so'
      end
    end
  end
end
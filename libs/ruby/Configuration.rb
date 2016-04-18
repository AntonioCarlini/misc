#!/usr/bin/env ruby 

require 'yaml'

module Configuration
  @@data = nil
  
  def self.load_data_once(file = nil)
      if file.nil?()
        file = File.dirname(__FILE__) + "/../../admin/configuration.data"
      end
      @@data = YAML.load_file(file)
  end       

  def self.get_value(key)
    self.load_data_once()
    return @@data[key]
  end

end # end of Installer

# Test cases
if __FILE__ == $0
  ["nis-master", "no-such-value", "nis-domain"].each() {
    |key|
    puts("#"*80 + "\nFind #{key}")
    result = Configuration::get_value(key)
    puts("#{key}: #{result}")
  }
end

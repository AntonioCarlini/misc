#!/usr/bin/env ruby 

require 'ipaddr'
require 'yaml'

module Host
  @@data = nil
  @@hosts = []

  class Host
    attr_reader :hardware
    attr_reader :ipv4s
    attr_reader :ipv6s
    attr_reader :name
    attr_reader :os
    
    def initialize(name, ipv4_addresses, ipv6_addresses, os, hardware)
      @name = name
      @ipv4s = ipv4_addresses
      @ipv6s = ipv6_addresses
      @os = os
      @hardware = hardware
    end
  end
  
  def self.load_data_once(file = nil)
      if file.nil?()
        file = File.dirname(__FILE__) + "/../../admin/systems/192.168.1.data"
      end
      data = YAML.load_file(file)
      data["hosts"].each() {
        |node|
        # Currently only support a single IPv4 address rather than a set of them
        ipv4 = IPAddr.new(node[1]["ipv4-address"])
        h = Host.new(node[0], [ ipv4 ], [], node[1]["os"], node[1]["hardware"])
        @@hosts << h
      }
  end       

  def self.each_host()
    self.load_data_once()
    @@hosts.each() { |host| yield host }
  end

  def self.get_host(name)
    self.load_data_once()
    return @@hosts.find() { |h| h.name() == name }
  end

end # end of Host

# Test cases
if __FILE__ == $0
  puts("List all hosts\n")
  Host::each_host() {
    |host|
    puts("Name: [%-10s] OS: [#{host.os()}]" % host.name())
  }

  puts("List one host (odrc2)")
  h = Host::get_host("odrc2")
  puts("name: #{h.name()} IPv4 address: #{h.ipv4s[0]} OS: #{h.os()} HW: #{h.hardware()}")
end

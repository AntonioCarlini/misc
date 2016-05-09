#!/usr/bin/env ruby 

require 'ipaddr'
require 'yaml'

module Host

  @@all_hosts = nil  # Hash of { hostname => Host }
  
  class Host
    attr_reader :comment
    attr_reader :domain
    attr_reader :hardware
    attr_reader :ipv4s
    attr_reader :ipv6s
    attr_reader :name
    attr_reader :netmask
    attr_reader :os
    
    def initialize(name, ipv4_addresses, ipv6_addresses, os, hardware, comment, domain, netmask)
      @name = name
      @ipv4s = ipv4_addresses
      @ipv6s = ipv6_addresses
      @os = (os || "")
      @hardware = (hardware || "")
      @comment = (comment || "")
      @domain = domain
      @netmask = netmask
    end
  end
  
  class Hosts
    attr_reader :domain
    attr_reader :netmask
    attr_reader :subnet

    def initialize(zone_filename)
      @data = YAML.load_file(zone_filename) 
      @hosts = []
      @virtual_hosts = []
      
      @domain = @data["domain"]
      @netmask = IPAddr.new(@data["netmask"])
      @subnet = IPAddr.new(@data["subnet"])

      @data["hosts"].each() {
        |node|
        # Currently only support a single IPv4 address rather than a set of them
        name = node[0]
        data = node[1]
        ipv4 = IPAddr.new(data["ipv4-address"])
        os = data["os"]
        hw = data["hardware"]
        comment = data["comment"]
        h = Host.new(name, [ ipv4 ], [], os, hw, comment, domain, netmask)
        @hosts << h
      } unless @data["hosts"].nil?()

      @data["virtual-hosts"].each() {
        |node|
        name = node[0]
        data = node[1]
        # TODO: this code should allow a virtual host to specify a hostname for the real host
        ipv4 = IPAddr.new(data["ipv4-address"])
        os = data["os"]
        hw = data["hardware"]
        comment = data["comment"]
        h = Host.new(name, [ ipv4 ], [], os, hw, comment, domain, netmask)
        @virtual_hosts << h
      } unless @data["virtual-hosts"].nil?()
    end

    def each_host()
      @hosts.each() { |host| yield host }
    end

    def get_host(name)
      return @hosts.find() { |h| h.name() == name }
    end

    def each_virtual_host()
      @virtual_hosts.each() { |host| yield host }
    end

    def get_virtual_host(name)
      return @virtual_hosts.find() { |h| h.name() == name }
    end
  end

  def self.load_all_hosts()
    return unless @@all_hosts.nil?()
    @@all_hosts = {}
    Dir.glob(File.dirname(__FILE__) + "/../../admin/systems/*.dns") {
      |src_file|
      zone_data = Hosts.new(File.expand_path(src_file))
      # Load up all hosts from this zone file.
      # It is assumed (and enforced) that all the host names be unique.
      zone_data.each_host() {
        |h|
        raise("Host name #{h.name()} is not unique.") if @@all_hosts.has_key?(h.name())
        @@all_hosts[h.name()] = h
      }
      zone_data.each_virtual_host() {
        |h|
        raise("Host name #{h.name()} is not unique.") if @@all_hosts.has_key?(h.name())
        @@all_hosts[h.name()] = h
      }
    }
  end

  def self.get_host(hostname)
    self.load_all_hosts()
    return @@all_hosts[hostname]
  end

end # end of Host

# Test cases
if __FILE__ == $0
  hosts = Host::Hosts.new(File.dirname(__FILE__) + "/../../admin/systems/192.168.1.flexbl.dns")
  puts("#"*80 + "\nList all hosts\n")
  hosts.each_host() {
    |host|
    puts("Name: [%-20s] OS: [#{host.os()}]" % host.name())
  }

  puts("#"*80 + "\nList one host (odrc2)")
  h = hosts.get_host("odrc2")
  puts("name: #{h.name()} IPv4 address: #{h.ipv4s[0]} OS: #{h.os()} HW: #{h.hardware()}")
end

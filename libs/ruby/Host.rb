#!/usr/bin/env ruby 

require 'ipaddr'
require 'yaml'

module Host
  @@data = nil
  @@hosts = []
  @@virtual_hosts = []
  @@domain = nil
  @@netmask = nil
  @@subnet = nil

  class Host
    attr_reader :comment
    attr_reader :hardware
    attr_reader :ipv4s
    attr_reader :ipv6s
    attr_reader :name
    attr_reader :os
    
    def initialize(name, ipv4_addresses, ipv6_addresses, os, hardware, comment)
      @name = name
      @ipv4s = ipv4_addresses
      @ipv6s = ipv6_addresses
      @os = (os || "")
      @hardware = (hardware || "")
      @comment = (comment || "")
    end
  end
  
  def self.load_data_once(file = nil)
    return unless @@data.nil?()
    if file.nil?()
      file = File.dirname(__FILE__) + "/../../admin/systems/192.168.1.data"
    end
    @@data = YAML.load_file(file)
    @@data["hosts"].each() {
      |node|
      # Currently only support a single IPv4 address rather than a set of them
      name = node[0]
      data = node[1]
      ipv4 = IPAddr.new(data["ipv4-address"])
      os = data["os"]
      hw = data["hardware"]
      comment = data["comment"]
      h = Host.new(name, [ ipv4 ], [], os, hw, comment)
      @@hosts << h
    }
    @@data["virtual-hosts"].each() {
      |node|
      name = node[0]
      data = node[1]
      # TODO: this code should allow a virtual host to specify a hostname for the real host
      ipv4 = IPAddr.new(data["ipv4-address"])
      os = data["os"]
      hw = data["hardware"]
      comment = data["comment"]
      h = Host.new(name, [ ipv4 ], [], os, hw, comment)
      @@virtual_hosts << h
    }
    @@domain = @@data["domain"]
    @@netmask = IPAddr.new(@@data["netmask"])
    @@subnet = IPAddr.new(@@data["subnet"])
  end       

  def self.each_host()
    self.load_data_once()
    @@hosts.each() { |host| yield host }
  end

  def self.get_host(name)
    self.load_data_once()
    return @@hosts.find() { |h| h.name() == name }
  end

  def self.each_virtual_host()
    self.load_data_once()
    @@virtual_hosts.each() { |host| yield host }
  end

  def self.get_virtual_host(name)
    self.load_data_once()
    return @@virtual_hosts.find() { |h| h.name() == name }
  end

  def self.domain()
    self.load_data_once()
    return @@domain
  end

  def self.netmask()
    self.load_data_once()
    return @@netmask
  end

  def self.subnet()
    self.load_data_once()
    return @@subnet
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

#!/usr/bin/env ruby

require "pathname.rb"
$LOAD_PATH.unshift(Pathname.new(__FILE__).realpath().dirname().dirname().dirname() + "libs" + "ruby")

require "Host.rb"

require "socket"
require "timeout"

module Systems

  # Builds a list of everything in the DNS database that could be considered to be a system.
  #
  # domain
  #   If supplied then only this domain's systems will be considered.
  #
  # The return value is an array of FQDN.
  #
  def self.hosts(domain = nil)
    hosts = Host::Hosts.new(File.dirname(__FILE__) + "/../../admin/systems/192.168.1.flexbl.dns")
    systems = []
    hosts.each_host() {
      |h|
      systems << h.name() + "." + h.domain() if h.systype() == "host"
    }
    return systems
  end
  
  # Builds a list of all systems that are considered to be reachable.
  # To be reachable a system needs to respond to SSH.
  # The return value is an array of FQDN.

  def self.reachable_hosts()
    hosts = Systems::hosts()     # start with a list of all hosts
    ssh_port = Socket.getservbyname("ssh")
    threads = []
    reachable = []
    errors = []
    hosts.each() {
      |host|
      threads << Thread.new() {
        begin
          timeout(3) {
            TCPSocket.new(host, ssh_port)
            reachable << host
          }
        rescue TimeoutError
          errors << "Timedout [#{host}]"
        rescue Errno::ECONNREFUSED
          errors << "Connection refused for [#{host}]"
        rescue SocketError
          errors << "Lookup failed for [#{host}]"
        rescue Errno::ENOENT
          errors << "ENOENT [#{host}]"
        rescue Errno::EHOSTUNREACH
          errors << "Host unreachable: [#{host}]"
        rescue Exception => e
          errors << "That went badly for #{host}: #{e.message()}"
        end
      }
    }
    threads.each() { |thread| thread.join() }
    return reachable
  end
  
end # end of Systems

# Test cases
if __FILE__ == $0
  puts("# Systems::hosts(): [")
  Systems::hosts().each() { |sys| puts(sys) }
  puts("]")
  puts("# Systems::reachable_hosts(): [")
  Systems::reachable_hosts().each() { |sys| puts(sys) }
  puts("]")
end

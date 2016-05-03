#!/usr/bin/env ruby

require "pathname.rb"
$LOAD_PATH.unshift(Pathname.new(__FILE__).realpath().dirname().dirname().dirname() + "libs" + "ruby")

require "Configuration.rb"
require "DnsZoneFile.rb"
require "Host.rb"

require 'getoptlong'

def main()

  # Stop if the chosen SOA record timers do not pass a sanity check
  DnsZoneFile::perform_sanity_check()
  
  # Parse arguments
  #
  # --forward
  #     Produce a DNS zone file
  #
  # --reverse
  #     Produce a DNS reverse zone file
  #
  # --verbose
  #     Currently unused
  #-
  options = GetoptLong.new(
    [ '--verbose',         '-v', GetoptLong::NO_ARGUMENT ],
    [ '--forward',         '-f', GetoptLong::NO_ARGUMENT ],
    [ '--reverse',         '-r', GetoptLong::NO_ARGUMENT ]
  )

  do_forward = false
  do_reverse = false
  verbose = false
  bad_option = false

  options.each() {
    |opt, arg|
    case opt
    when '--forward'
      do_forward = true
    when '--reverse'
      do_reverse = true
    when '--verbose'
      do_verbose = true
    else
      $stderr.puts("Unrecognised option: [#{opt}]")
      bad_option = true
    end
  }

  exit(1) if bad_option

  dns_files = []
  
  Dir.glob(File.dirname(__FILE__) + "/../systems/*.dns") {
    |file|
    zone_data = Host::Hosts.new(File.expand_path(file))
  
    hosts = []
    virtual_hosts = []

    zone_data.each_host() { |h| hosts << h }
    zone_data.each_virtual_host() { |h| virtual_hosts << h }

    # Sort by IP address
    hosts.sort!() { |a,b| a.ipv4s[0].to_i() <=> b.ipv4s[0].to_i() }
    virtual_hosts.sort!() { |a,b| a.ipv4s[0].to_i() <=> b.ipv4s[0].to_i() }

    DnsZoneFile::build_dns_forward_file($stdout, hosts, virtual_hosts, zone_data.domain()) if do_forward
    DnsZoneFile::build_dns_reverse_file($stdout, hosts, virtual_hosts, zone_data.domain(), zone_data.subnet()) if do_reverse
  }
  
end

# Invoke the main function to kick off processing
main()

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
  
  # Parse arguments.
  #
  # --dry-run
  #     Create the temporary files but leave them in the temporary directory
  #
  # --verbose
  #     Currently unused
  #-
  options = GetoptLong.new(
    [ '--verbose',         '-v', GetoptLong::NO_ARGUMENT ],
    [ '--dry-run',         '-n', GetoptLong::NO_ARGUMENT ],
  )

  dry_run = false
  verbose = false
  bad_option = false

  options.each() {
    |opt, arg|
    case opt
    when '--dry-run'
      dry_run = true
    when '--verbose'
      verbose = true
    else
      $stderr.puts("Unrecognised option: [#{opt}]")
      bad_option = true
    end
  }

  exit(1) if bad_option

  dns_files = []
  
  # Create a fresh temporary directory.
  # Try up to 3 times at short intervals (the constructed name depends on the time).
  create_attempt_left = 3
  begin
    t = Time.now()
    temp_dir = "/tmp/dns-rebuid.#{Process.pid()}.#{t.strftime('%Y%m%d%H%M%S%L')}/"
    temp_dir = "/tmp/dns-rebuid.0.0/" if dry_run
    Dir.mkdir(temp_dir)
  rescue SystemCallError
    create_attempt_left -= 1
    if create_attempt_left > 0
      sleep 0.5
      retry
    else
      $stderr.puts("Failed to create unique temporary directory of the form #{temp_dir}")
      exit(1)
    end
  end
  
  # For each zone, build of forward and reverse files, keeping track in named.conf.local
  File.open(temp_dir + "named.conf.local", "w") {
    |conf_file|
    DnsZoneFile::write_configuration_file_header(conf_file)

    Dir.glob(File.dirname(__FILE__) + "/../systems/*.dns") {
      |src_file|
      zone_data = Host::Hosts.new(File.expand_path(src_file))

      forward_zone_file_name = zone_data.domain() + ".local"
      reverse_zone_file_name = zone_data.subnet().to_s() + ".rev"

      reverse_zone_file = File.open(temp_dir + reverse_zone_file_name, "w")
    
      hosts = []
      virtual_hosts = []

      zone_data.each_host() { |h| hosts << h }
      zone_data.each_virtual_host() { |h| virtual_hosts << h }

      # Sort by IP address
      hosts.sort!() { |a,b| a.ipv4s[0].to_i() <=> b.ipv4s[0].to_i() }
      virtual_hosts.sort!() { |a,b| a.ipv4s[0].to_i() <=> b.ipv4s[0].to_i() }

      # Build the forward and reverse files
      File.open(temp_dir + forward_zone_file_name, "w") {
        |fwd_zone_file|
        DnsZoneFile::build_dns_forward_file(fwd_zone_file, hosts, virtual_hosts, zone_data.domain())
      }

      File.open(temp_dir + reverse_zone_file_name, "w") {
        |rev_zone_file|
        DnsZoneFile::build_dns_reverse_file(rev_zone_file, hosts, virtual_hosts, zone_data.domain(), zone_data.subnet())
      }

      # Update the configuration file
      DnsZoneFile::add_to_configuration_file(conf_file, forward_zone_file_name, reverse_zone_file_name, zone_data.domain(), zone_data.subnet())
    }
  }
  # TODO
  # Remove identical files, move the rest to the active bind area
  # Get bind to notice
  # Dir.rmdir(temp_dir)  
end

# Invoke the main function to kick off processing
main()

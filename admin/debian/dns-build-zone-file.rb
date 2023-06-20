#!/usr/bin/env ruby

require "pathname.rb"
$LOAD_PATH.unshift(Pathname.new(__FILE__).realpath().dirname().dirname().dirname() + "libs" + "ruby")

require "Configuration.rb"
require "DnsZoneFile.rb"
require "Host.rb"

require 'fileutils'
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

  exit(1) if ARGV.length > 1

  print "ARGV len = ", ARGV.length(), "\n"
  
  if ARGV.length == 1
    dns_files_dir = ARGV.shift()
    dns_files_dir += "/" unless dns_files_dir[-1] == "/"
  else
    dns_files_dir = File.dirname(__FILE__) + "/../systems/"
  end

  print "Will look for DNS files in ", dns_files_dir, "\n"
  
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

    ## TODO: fix this to provide an alternative
    Dir.glob(dns_files_dir + "*.dns") {
      |src_file|
      printf "Processing DNS file ", src_file, "\n"
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

  # Prepare options for FileUtils calls.
  file_options = {}
  file_options[:verbose] = true if verbose
  file_options[:noop] = true if dry_run
  gen_file_options = file_options.dup()
  gen_file_options.delete(:noop)   # Used for file operations (other than move) on a generated file

  file_changed = false
  
  # Remove identical files, move the rest to the active bind area.
  # Note that the config needs to be handled specially: it moves to a different area and moves after everything else.
  # Further note that out-of-date zone files are NOT removed from the /etc/bind directory tree.
  update_config_file = false
  config_dns_file = nil
  config_gen_file = nil
  Dir.glob(temp_dir + "*") {
    |file|
    basename = File.basename(file)
    gen_file = File.expand_path(file)
    if basename == "named.conf.local"
      config_dns_file = "/etc/bind/#{basename}"
      config_gen_file = gen_file.dup()
      if FileUtils.identical?(config_gen_file, config_dns_file)
        puts("config file #{config_dns_file} unchanged.") if verbose
        FileUtils.rm(gen_file, **gen_file_options)
      else
        puts("config file #{config_dns_file} to be updated.") if verbose
        update_config_file = true
        file_changed = true
      end
    else
      dns_file = "/etc/bind/zones/master/#{basename}"
      if DnsZoneFile::zone_files_functionally_identical?(gen_file, dns_file)
        puts("zone file #{dns_file} unchanged.") if verbose
        FileUtils.rm(gen_file, **gen_file_options)
      else
        puts("zone file #{dns_file} to be updated.") if verbose
        FileUtils.mv(gen_file, dns_file, **file_options)
        file_changed = true
      end
    end
  }
  # Now that the zone files are present and correct, move the config file (if required)
  FileUtils.mv(config_gen_file, config_dns_file, **file_options) if update_config_file
  
  # TODO
  # Get bind to notice
  FileUtils.rmtree(temp_dir, **gen_file_options)

  if file_changed
    puts("BIND needs to be restarted") if verbose
    return 1
  end
  return 0
end

# Invoke the main function to kick off processing
result = main()
exit(result)

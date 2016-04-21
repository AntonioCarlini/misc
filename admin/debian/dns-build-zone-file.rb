#!/usr/bin/env ruby

require "pathname.rb"

MISC_DIR = Pathname.new(__FILE__).realpath().dirname().dirname().dirname()
$LOAD_PATH.unshift(MISC_DIR + "libs" + "ruby")

require "Configuration.rb"
require "Host.rb"

require 'getoptlong'

def main()

  # Stop if the chosen SOA record timers do not pass a sanity check
  perform_sanity_check()
  
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

  hosts = []
  virtual_hosts = []

  Host::each_host() { |h| hosts << h }
  Host::each_virtual_host() { |h| virtual_hosts << h }

  # Sort by IP address
  hosts.sort!() { |a,b| a.ipv4s[0].to_i() <=> b.ipv4s[0].to_i() }
  virtual_hosts.sort!() { |a,b| a.ipv4s[0].to_i() <=> b.ipv4s[0].to_i() }

  display_dns_forward_file(hosts, virtual_hosts) if do_forward
  display_dns_reverse_file(hosts, virtual_hosts) if do_reverse
end

# Builds a DNS zone file.
# Note that dns-compare-zone-files.rb depends on the output format used here.
def display_dns_forward_file(hosts, virtual_hosts)
  domain = Host::domain()
  serial = make_serial_number()
  refresh = "%8.8s" % get_refresh_interval()
  retry_delay = "%8.8s" % get_retry_interval()
  expiration = "%8.8s" % get_expiration_interval()
  default_ttl = "%8.8s" % get_default_ttl()
  puts(";")
  puts("; BIND data file for #{domain}, built by #{File.basename(__FILE__)} on #{Time.now()}")
  puts(";")
  puts("@       IN      SOA     #{domain}. root.#{domain}. (")
  puts("                     #{serial}         ; Serial")
  puts("                            #{refresh}         ; Refresh")
  puts("                            #{retry_delay}         ; Retry")
  puts("                            #{expiration}         ; Expire")
  puts("                            #{default_ttl} )       ; Default TTL")
  puts("     ")

  puts("             IN      NS      arpione.#{domain}.")
  puts(";;           IN      MX      10 mail.#{domain}.")
  puts("     ")
  hosts.each() {
    |h|
    hn = "%-15.15s" % h.name()
    comment = h.comment()
    comment = "      ; #{comment}" unless h.comment().empty?()
    puts("#{hn} IN      A       #{h.ipv4s[0]}#{comment}")
  }
  puts("")
  puts(";; Virtual hosts for apache")
  virtual_hosts.each() {
    |h|
    hn = "%-15.15s" % h.name()
    comment = h.comment()
    comment = "      ; #{comment}" unless h.comment().empty?()
    puts("#{hn} IN      A       #{h.ipv4s[0]}#{comment}")
  }

end

# Note that dns-compare-zone-files.rb depends on the output format used here.
def display_dns_reverse_file(hosts, virtual_hosts)
  domain = Host::domain()
  subnet = Host::subnet()
  serial = make_serial_number()
  refresh = "%8.8s" % get_refresh_interval()
  retry_delay = "%8.8s" % get_retry_interval()
  expiration = "%8.8s" % get_expiration_interval()
  default_ttl = "%8.8s" % get_default_ttl()
  puts(";")
  puts("; BIND data file for #{subnet}, built by #{File.basename(__FILE__)} on #{Time.now()}")
  puts(";")
  puts("@       IN      SOA     #{domain}. root.#{domain}. (")
  puts("                     #{serial}         ; Serial")
  puts("                            #{refresh}         ; Refresh")
  puts("                            #{retry_delay}         ; Retry")
  puts("                            #{expiration}         ; Expire")
  puts("                            #{default_ttl} )       ; Default TTL")
  puts("     ")
  rev = subnet.reverse()
  dot = rev.index(".")
  r = rev[dot+1..-1]
  puts("#{r}.             IN      NS      #{domain}.")
  puts("     ")
  hosts.each() {
    |h|
    print("%-7d" % h.ipv4s[0].mask("0.0.0.255").to_i())
    puts(" IN      PTR     #{h.name()}.#{domain}.")
  }
end

#+
# Builds a suitable serial number for a DNS zone file.
# Does this by finding the date/time to the nearest millisecond.
# bind truncates this to a 32-bit number. At the time of writing
# the result of this is 46939 into the new 2**32 block and so this
# number is not expected to wrap for another 13 years or so.
#-
def make_serial_number()
  Time.now().strftime("%Y%m%d%H%M%S%1N")
end

# The time (in seconds) that a secondary DNS server waits before polling for an update.
def get_refresh_interval()
  return 60*60*24*7
end

# The time (in seconds) that a secondary DNS server waits after failing to contact
# the primary DNS server before it tries again.
def get_retry_interval()
  return 60*60*24
end

# How long a secondary DNS server treats its data as valid.
def get_expiration_interval()
  return 60*60*24*28
end

# How long other nameservers can cache values supplied by this nameserver.
def get_default_ttl()
  return 60*60*24*7
end

def perform_sanity_check()
  # Quick sanity check.
  #
  # RFC 1912 points out that:
  # a) retry is usually a fraction of refresh.
  # b) expiration must be greater than default TTL and retry.

  # Halt if any of these is not true.

  refresh = get_refresh_interval()
  retry_delay = get_retry_interval()
  expiration = get_expiration_interval()
  default_ttl = get_default_ttl()
  values_sane = true

  if retry_delay >= refresh
    $stderr.puts("RETRY value (#{retry_delay}) must be smaller than REFRESH (#{refresh}).")
    values_sane = false
  end

  if expiration <= retry_delay
    $stderr.puts("EXPIRATION value (#{expiration}) must be greater than RETRY (#{retry_delay}).")
    values_sane = false
  end

  if expiration <= default_ttl
    $stderr.puts("EXPIRATION value (#{expiration}) must be greater than DEFAULT TTL (#{default_ttl}).")
    values_sane = false
  end

  exit(1) unless values_sane
end

# Invoke the main function to kick off processing
main()

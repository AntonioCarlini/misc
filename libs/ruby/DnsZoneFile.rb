#!/usr/bin/env ruby

$LOAD_PATH.unshift(File.dirname(__FILE__))

module DnsZoneFile

  # file is expected to be a File (e.g. $stdout)
  # hosts is an Array of Host
  # virtual_hosts is an Array of Host
  # domain is the fully qualified domain name
  def self.build_dns_forward_file(file, hosts, virtual_hosts, domain)
    serial = make_serial_number()
    refresh = "%8.8s" % get_refresh_interval()
    retry_delay = "%8.8s" % get_retry_interval()
    expiration = "%8.8s" % get_expiration_interval()
    default_ttl = "%8.8s" % get_default_ttl()
    file.puts(";")
    file.puts("; BIND data file for #{domain}, built by #{File.basename(__FILE__)} on #{Time.now()}")
    file.puts(";")
    file.puts("@       IN      SOA     #{domain}. root.#{domain}. (")
    # Note that dns-compare-zone-files.rb depends on the output format of the Serial line here
    file.puts("                     #{serial}         ; Serial")
    file.puts("                            #{refresh}         ; Refresh")
    file.puts("                            #{retry_delay}         ; Retry")
    file.puts("                            #{expiration}         ; Expire")
    file.puts("                            #{default_ttl} )       ; Default TTL")
    file.puts("     ")

    file.puts("             IN      NS      arpione.#{domain}.")
    file.puts(";;           IN      MX      10 mail.#{domain}.")
    file.puts("     ")
    hosts.each() {
      |h|
      hn = "%-15.15s" % h.name()
      comment = h.comment()
      comment = "      ; #{comment}" unless h.comment().empty?()
      file.puts("#{hn} IN      A       #{h.ipv4s[0]}#{comment}")
    }
    file.puts("")
    file.puts(";; Virtual hosts for apache")
    virtual_hosts.each() {
      |h|
      hn = "%-15.15s" % h.name()
      comment = h.comment()
      comment = "      ; #{comment}" unless h.comment().empty?()
      file.puts("#{hn} IN      A       #{h.ipv4s[0]}#{comment}")
    }
  end

  # file is expected to be a File (e.g. $stdout)
  # hosts is an Array of Host
  # virtual_hosts is an Array of Host
  # domain is the fully qualified domain name (e.g. flexbl.co.uk)
  # subnet is the subnet (e.g. 192.168.1.0)
  def self.build_dns_reverse_file(file, hosts, virtual_hosts, domain, subnet)
    serial = make_serial_number()
    refresh = "%8.8s" % get_refresh_interval()
    retry_delay = "%8.8s" % get_retry_interval()
    expiration = "%8.8s" % get_expiration_interval()
    default_ttl = "%8.8s" % get_default_ttl()
    file.puts(";")
    file.puts("; BIND data file for #{subnet}, built by #{File.basename(__FILE__)} on #{Time.now()}")
    file.puts(";")
    file.puts("@       IN      SOA     #{domain}. root.#{domain}. (")
    # Note that dns-compare-zone-files.rb depends on the output format of the Serial line here
    file.puts("                     #{serial}         ; Serial")
    file.puts("                            #{refresh}         ; Refresh")
    file.puts("                            #{retry_delay}         ; Retry")
    file.puts("                            #{expiration}         ; Expire")
    file.puts("                            #{default_ttl} )       ; Default TTL")
    file.puts("     ")
    rev = subnet.reverse()
    dot = rev.index(".")
    r = rev[dot+1..-1]
    file.puts("#{r}.             IN      NS      #{domain}.")
    file.puts("     ")
    hosts.each() {
      |h|
      print("%-7d" % h.ipv4s[0].mask("0.0.0.255").to_i())
      file.puts(" IN      PTR     #{h.name()}.#{domain}.")
    }
  end

  def self.perform_sanity_check()
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

  #+
  # Builds a suitable serial number for a DNS zone file.
  # Does this by finding the date/time to the nearest millisecond.
  # bind truncates this to a 32-bit number. At the time of writing
  # the result of this is 46939 into the new 2**32 block and so this
  # number is not expected to wrap for another 13 years or so.
  #-
  def self.make_serial_number()
    Time.now().strftime("%Y%m%d%H%M%S%1N")
  end
  private_class_method :make_serial_number

  # The time (in seconds) that a secondary DNS server waits before polling for an update.
  def self.get_refresh_interval()
    return 60*60*24*7
  end
  private_class_method :get_refresh_interval

  # The time (in seconds) that a secondary DNS server waits after failing to contact
  # the primary DNS server before it tries again.
  def self.get_retry_interval()
    return 60*60*24
  end
  private_class_method :get_retry_interval

  # How long a secondary DNS server treats its data as valid.
  def self.get_expiration_interval()
    return 60*60*24*28
  end
  private_class_method :get_expiration_interval

  # How long other nameservers can cache values supplied by this nameserver.
  def self.get_default_ttl()
    return 60*60*24*7
  end
  private_class_method :get_default_ttl

end # end of DnsZoneFile

# Test cases
if __FILE__ == $0
  require "Host.rb"
  require "ipaddr.rb"

  h = Host::Host.new("test", [ IPAddr.new("192.168.0.1") ], nil, "debian", "none", "test-case")
  hosts = [ h ]
  puts("#"*80 + "\nGenerate a DNS forward file")
  DnsZoneFile::build_dns_forward_file($stdout, hosts, [], "test.co.uk")
  puts("#"*80 + "\nGenerate a DNS reverse file")
  DnsZoneFile::build_dns_reverse_file($stdout, hosts, [], "test.co.uk", IPAddr.new("192.168.0.0"))
  puts("#"*80 + "\nPerform an internal sanity check")
  DnsZoneFile::perform_sanity_check()
  puts("#"*80 + "\nTry to access a private method")
  begin
    DnsZoneFile::make_serial_number()
  rescue NoMethodError
    puts("NoMethodError seen, as expected")
  else
    puts("NoMethodError NOT seen, something is WRONG!")
  end
end

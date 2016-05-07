#!/usr/bin/ruby -w

require "pathname.rb"
$LOAD_PATH.unshift(Pathname.new(__FILE__).realpath().dirname().dirname().dirname() + "libs" + "ruby")

require "Configuration.rb"
require "Host.rb"
require "Shell.rb"

module InstallHostnameAndAddress
  
  def self.install(options)
    message(options, "Nothing to install for hostname and IP address")
  end
  
  def self.configure(options, hostname, do_ipv4)

    if !hostname.nil?() && !hostname.empty?()
      message(options, "Configure host name")
      configure_hostname(options, hostname)
    end

    configure_ipv4_address(options, hostname) if do_ipv4
  end
    
  def self.configure_hostname(options, hostname)
    shell_options = []
    shell_options << :dry_run if options.dry_run?()

    hostname_file = options.dry_run?() ? "/dev/null" : "/etc/hostname"

    # Set up the require /etc/hostname file
    message(options, "Writing hostname (#{hostname}) to #{hostname_file}")
    File.open(hostname_file, "w") { |file| file.write("#{hostname}\n") }

    # Edit the existing /etc/hosts file to change the current host to the new one
    Shell::execute_shell_commands("cp /etc/hosts /etc/hosts.original; cat /etc/hosts.original | sed -e 's/127.0.1.1.*/127.0.1.1       #{hostname}/' > /etc/hosts", shell_options)
  end

  def self.configure_ipv4_address(options, hostname)
    return # TODO needs to be reworked to use new Host module interface
=begin
    dns_master = Configuration::get_value("dns-master")
    dns_extras = Configuration::get_value("dns-extras")
    gateway = Configuration::get_value("ipv4-gateway")
    netmask = Hosts::netmask()
    domain = Hosts::domain()

    # Find the IPv4 address from the host name
    h = Host::get_host(hostname)
    if h.nil?()
      $stderr.puts("Cannot find host #{hostname}. Make sure an entry exists in the data file in admin/systems")
    end
    ipv4_address = h.ipv4s().first()

    interfaces_file = "/etc/network/interfaces"
    
    # If --dry-run, do not write to /etc/interfaces; either write to the terminal or write nowhere
    interfaces_file = options.verbose?() ? "/dev/tty" : "/dev/null" if options.dry_run?()

    message(options, "/etc/interfaces would be replaced with [") if options.dry_run?()
    File.open(interfaces_file, "w") {
      |file|
      file.write("# interfaces(5) file used by ifup(8) and ifdown(8)\n\n")
      file.write("auto lo\n")
      file.write("iface lo inet loopback\n\n")
      file.write("auto eth0\n")
      file.write("iface eth0 inet static\n")
      file.write("  address #{ipv4_address}\n")
      file.write("  netmask #{netmask}\n")
      file.write("  gateway #{gateway}\n")
      file.write("  dns-nameservers #{dns_master} #{dns_extras}\n")
      file.write("  dns-search #{domain}\n\n")
    }
    # Cannot use message() for this as the __FIL__ prefix looks wrong.
    puts("]") if options.dry_run?() && options.verbose?()
=end
  end

  def self.message(options, message)
    puts("#{File.basename(__FILE__)}: #{message}") if options.verbose?()
  end

end # end of InstallHostnameAndAddress

# Test cases
if __FILE__ == $0
  require "Installer.rb"
  ARGV.clear()
  ARGV << "--dry-run"
  ARGV << "--verbose"
  options = Installer::parse_options()
  host = "flexpc"
  puts("# Configure host #{host}, no address (dry run, verbose) ")
  InstallHostnameAndAddress::configure(options, "flexpc", false)
end

#!/usr/bin/env ruby

require "pathname.rb"
$LOAD_PATH.unshift(Pathname.new(__FILE__).realpath().dirname().dirname().dirname() + "libs" + "ruby")

require "InstallHostnameAndAddress.rb"
require "Installer.rb"

#+
# Sets up the host name (and IP address configuration if required)a.
#
# --install
#    Does nothing.
#
# --configure
#    Performs just configuration.
#
# --dry-run
#    Change nothing but report on possible errors.
#
# --verbose
#    Log progress.
#
# --host name
#    If supplied then the hostname will be set.
#
# --no-ipv4
#    If specified and --host is also specified, no attempt will be made to set the IPv4 address.
#    Note that currently there is no support for IPv6.
#-
def main()

  host = nil
  do_ipv4 = true
  options = Installer::parse_options(
                                     [ '--host',            '-h', GetoptLong::REQUIRED_ARGUMENT ],
                                     [ '--no-ipv4',         '-4', GetoptLong::NO_ARGUMENT ]
                                     ) {

    |opt, arg|
    case opt
    when '--host'
      host = arg.dup()
    when '--no-ipv4'
      do_ipv4 = false
    else
      # GetoptLong will raise an exception for a real error, so this is an extra option that the code has forgotten to parse.
      $stderr.puts("Unknown option: #{opt} #{arg}")
    end
  }

  if host.nil?() || host.empty?()
    $stderr.puts("Usage: #{File.basename(__FILE__)} --host hostnam [--no-ipv4]")
    exit(1)
  end

  # Perform the installation and configuration as required.
  InstallHostnameAndAddress::configure(options, host, do_ipv4) if options.configure?()

end

# Invoke the main function.
main()

#!/usr/bin/env ruby

require "pathname.rb"
$LOAD_PATH.unshift(Pathname.new(__FILE__).realpath().dirname().dirname().dirname() + "libs" + "ruby")

require "Package.rb"

require "fileutils.rb"

module InstallDnsServer
  
  def self.install(options)
    apt_options = []
    apt_options << :dry_run if options.dry_run?()

    apt_packages = []
    apt_packages << "bind9"
    apt_packages << "dnsutils"

    # Install the necessary packages via apt
    message(options, "Installing apt packages")
    Package::install_apt_packages(apt_packages, apt_options)
  end
  
  def self.configure(options)
    mkpath_options = {}
    mkpath_options[:verbose] = true if options.verbose?()
    mkpath_options[:noop] = true if options.dry_run?()
    FileUtils.mkpath('/etc/bind/zones/master', mkpath_options)
  end

  def self.message(options, message)
    puts("#{File.basename(__FILE__)}: #{message}") if options.verbose?()
  end

end # end of InstallDnsServer

# Test cases
if __FILE__ == $0
  require "Installer.rb"
  ARGV.clear()
  ARGV << "--dry-run"
  ARGV << "--verbose"
  options = Installer::parse_options()
  puts("# Install DNS server (dry run, verbose)")
  InstallDnsServer::install(options)
  puts("# Configure DNS server (dry run, verbose)")
  InstallDnsServer::configure(options)
end

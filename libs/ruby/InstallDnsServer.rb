#!/usr/bin/env ruby

require "pathname.rb"
$LOAD_PATH.unshift(Pathname.new(__FILE__).realpath().dirname().dirname().dirname() + "libs" + "ruby")

require "Package.rb"

require "fileutils.rb"

module InstallDnsServer
  
  def self.install(installer_options)
    apt_options = []
    apt_options << :dry_run if installer_options.dry_run?()

    apt_packages = []
    apt_packages << "bind9"
    apt_packages << "dnsutils"

    # Install the necessary packages via apt
    message(installer_options, "Installing apt packages")
    Package::install_apt_packages(apt_packages, apt_options)
  end
  
  def self.configure(installer_options)
    mkpath_options = {}
    mkpath_options[:verbose] = true if installer_options.verbose?()
    mkpath_options[:noop] = true if installer_options.dry_run?()
    FileUtils.mkpath('/etc/bind/zones/master', mkpath_options)
  end

  def self.message(installer_options, message)
    puts("#{File.basename(__FILE__)}: #{message}") if installer_options.verbose?()
  end

end # end of InstallDnsServer

# Test cases
if __FILE__ == $0
  require "InstallerOptions.rb"
  ARGV.clear()
  ARGV << "--dry-run"
  ARGV << "--verbose"
  installer_options = Installer::parse_options()
  puts("# Install DNS server (dry run, verbose)")
  InstallDnsServer::install(installer_options)
  puts("# Configure DNS server (dry run, verbose)")
  InstallDnsServer::configure(installer_options)
end

#!/usr/bin/env ruby

require "pathname.rb"
$LOAD_PATH.unshift(Pathname.new(__FILE__).realpath().dirname().dirname().dirname() + "libs" + "ruby")

require "Package.rb"

module InstallNisServer
  
  def self.install(installer_options)
    apt_options = []
    apt_options << :dry_run if installer_options.dry_run?()

    apt = []
    apt << "nis"
    apt << "portmap"

    # Install the necessary packages via apt
    message(installer_options, "Installing apt packages")
    Package::install_apt_packages(apt_packages, apt_options)
  end
  
  def self.configure(installer_options)
    shell_options = []
    shell_options << :dry_run if installer_options.dry_run?()

    # Edit /etc/default/nis and change the NISMASTER line to
    #   NISSERVER=master
    # domainname flexbl
    # server:~# cat /etc/nsswitch.conf
    # passwd: compat
    # group: compat      
    # shadow: compat     
    # netgroup: nis      
    # /usr/lib/yp/ypinit -m
    # After a reboot:
    # /etc/init.d/rpcbind start
    # /etc/init.d/nis start
  end

  def self.message(installer_options, message)
    puts("#{File.basename(__FILE__)}: #{message}") if installer_options.verbose?()
  end

end # end of InstallNisServer

# Test cases
if __FILE__ == $0
  require "Installer.rb"
  ARGV.clear()
  ARGV << "--dry-run"
  ARGV << "--verbose"
  installer_options = Installer::parse_options()
  puts("# Install nis server (dry run, verbose)")
  InstallNisServer::install(installer_options)
  puts("# Configure nis server (dry run, verbose)")
  InstallNisServer::configure(installer_options)
end

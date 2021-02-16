#!/usr/bin/env ruby

require "pathname.rb"
$LOAD_PATH.unshift(Pathname.new(__FILE__).realpath().dirname().dirname().dirname() + "libs" + "ruby")

require "Package.rb"

module InstallWebServer
  
  def self.install(installer_options)
    apt_options = []
    apt_options << :dry_run if installer_options.dry_run?()

    #prepare_mysql(actions)
    apt_packages = []
    apt_packages << "apache2"
    apt_packages << "apache2-doc"
    apt_packages << "apache2-utils"
    apt_packages << "php5"
    apt_packages << "php5-mysql"

    # Install the necessary packages via apt
    message(installer_options, "Installing apt packages")
    Package::install_apt_packages(apt_packages, apt_options)

  end
  
  def self.configure(installer_options)
    shell_options = []
    shell_options << :dry_run if installer_options.dry_run?()
  end

  def self.message(installer_options, message)
    puts("#{File.basename(__FILE__)}: #{message}") if installer_options.verbose?()
  end

end # end of InstallWebServer

# Test cases
if __FILE__ == $0
  require "InstallerOptions.rb"
  ARGV.clear()
  ARGV << "--dry-run"
  ARGV << "--verbose"
  installer_options = Installer::parse_options()
  puts("# Install web server (dry run, verbose)")
  InstallWebServer::install(installer_options)
  InstallWebServer::configure(installer_options)
end

#!/usr/bin/env ruby

require "pathname.rb"
$LOAD_PATH.unshift(Pathname.new(__FILE__).realpath().dirname().dirname().dirname() + "libs" + "ruby")

require "Package.rb"

module InstallWebServer
  
  def self.install(options)
    apt_options = []
    apt_options << :dry_run if options.dry_run?()

    #prepare_mysql(actions)
    apt_packages = []
    apt_packages << "apache2"
    apt_packages << "apache2-doc"
    apt_packages << "apache2-utils"
    apt_packages << "php5"
    apt_packages << "php5-mysql"

    # Install the necessary packages via apt
    message(options, "Installing apt packages")
    Package::install_apt_packages(apt_packages, apt_options)

  end
  
  def self.configure(options)
    shell_options = []
    shell_options << :dry_run if options.dry_run?()
  end

  def self.message(options, message)
    puts("#{File.basename(__FILE__)}: #{message}") if options.verbose?()
  end

end # end of InstallWebServer

# Test cases
if __FILE__ == $0
  require "Installer.rb"
  ARGV.clear()
  ARGV << "--dry-run"
  ARGV << "--verbose"
  options = Installer::parse_options()
  puts("# Install web server (dry run, verbose)")
  InstallWebServer::install(options)
  InstallWebServer::configure(options)
end

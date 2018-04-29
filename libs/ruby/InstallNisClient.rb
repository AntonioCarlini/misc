#!/usr/bin/ruby -w

require "pathname.rb"
$LOAD_PATH.unshift(Pathname.new(__FILE__).realpath().dirname().dirname().dirname() + "libs" + "ruby")

require "Configuration.rb"
require "Package.rb"
require "Shell.rb"

module InstallNisClient
  
  def self.install(installer_options)
    apt_options = []
    apt_options << :dry_run if installer_options.dry_run?()

    # Install the nis package silently by preseeding the required values.
    message(installer_options, "Installing (pre-seeded) apt packages")
    nis_domain = Configuration::get_value("nis-domain")
    Package::install_apt_preseed_package("nis nis/domain string #{nis_domain}", "nis", apt_options)
  end
  
  def self.configure(installer_options)
    shell_options = []
    shell_options << :dry_run if installer_options.dry_run?()

    # Ensure that the required domain name is set
    nis_domain = Configuration::get_value("nis-domain")
    Shell::execute_shell_commands("domainname #{nis_domain}", shell_options)
  end

  def self.message(installer_options, message)
    puts("#{File.basename(__FILE__)}: #{message}") if installer_options.verbose?()
  end

end # end of InstallNisClient

# Test cases
if __FILE__ == $0
  require "Installer.rb"
  ARGV.clear()
  ARGV << "--dry-run"
  ARGV << "--verbose"
  installer_options = Installer::parse_options()
  puts("# Install nis client (dry run, verbose)")
  InstallNisClient::install(installer_options)
  puts("# Configure nis client (dry run, verbose)")
  InstallNisClient::configure(installer_options)
end

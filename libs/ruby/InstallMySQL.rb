#!/usr/bin/env ruby

require "pathname.rb"
$LOAD_PATH.unshift(Pathname.new(__FILE__).realpath().dirname())

require "Package.rb"

require "socket.rb"

module InstallMySQL
  
  def self.install(installer_options)
    apt_options = []
    apt_options << :dry_run if installer_options.dry_run?()

    password = "." + Socket.gethostbyname(Socket.gethostname()).first()

    # Install the mysql package silently by preseeding the required values.
    message(installer_options, "Installing (pre-seeded) mysql-server")
    mysql_seeds = []
    mysql_seeds << "mysql-server-5.5 mysql-server/root_password password #{password}"
    mysql_seeds << "mysql-server-5.5 mysql-server/root_password_again password #{password}"
    Package::install_apt_preseed_package(mysql_seeds, "mysql-server", apt_options)

    message(installer_options, "Installing phpmyadmin")
    apt_packages = []
    apt_packages << "php-mysql"
    Package::install_apt_packages(apt_packages, apt_options)

    # phpmyadmin itself needs to be pre-seeded
    phpmyadmin_seeds = []
    phpmyadmin_seeds << "phpmyadmin phpmyadmin/mysql/app-pass password #{password}"
    Package::install_apt_preseed_package(phpmyadmin_seeds, "phpmyadmin", apt_options)
  end

  def self.configure(installer_options)
    # TODO (note this asks questions) sudo mysql_secure_installation
  end

  def self.message(installer_options, message)
    puts("#{File.basename(__FILE__)}: #{message}") if installer_options.verbose?()
  end

end # end of InstallMySQL

# Test cases
if __FILE__ == $0
  require "InstallerOptions.rb"
  ARGV.clear()
  ARGV << "--dry-run"
  ARGV << "--verbose"
  installer_options = Installer::parse_options()
  puts("# Install MySQL (dry run, verbose)")
  InstallMySQL::install(installer_options)
  puts("# Configure MySQL (dry run, verbose)")
  InstallMySQL::configure(installer_options)
end

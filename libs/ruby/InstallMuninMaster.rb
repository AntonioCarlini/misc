#!/usr/bin/env ruby

require "pathname.rb"
$LOAD_PATH.unshift(Pathname.new(__FILE__).realpath().dirname().dirname().dirname() + "libs" + "ruby")

require "InstallWebServer.rb"
require "Package.rb"
require "Shell.rb"

module InstallMuninMaster
  
  def self.install(options)
    apt_options = []
    apt_options << :dry_run if options.dry_run?()

    apt = []
    apt << "apache2"
    apt << "apache2-utils"
    apt << "libapache2-mod-fcgid"
    apt << "libcgi-fast-perl"
    apt << "munin"
    apt << "munin-plugins-extra"

    # Install the necessary packages via apt
    message(options, "Installing apt packages")
    Package::install_apt_packages(apt_packages, apt_options)

    InstallWebServer::install(options)
  end
  
  def self.configure(options)
    shell_options = []
    shell_options << :dry_run if options.dry_run?()

    InstallWebServer::install(options)

    # /etc/munin/munin.conf: enable directories ; change localhost.localdomain to munin-id
    cmd = "cat /etc/munin/munin.conf | sed -r -e 's/#(db|html|log|run|tmpl)dir/\\1dir/g' -e 's/localhost.localdomain/MuninMaster/' > /etc/munin/munin.conf.mod"
    Shell::execute_shell_commands(cmd, options)
    # Shell::execute_shell_commands("mv /etc/munin/munin.conf.mod /etc/munin/munin.conf")
    Shell::execute_shell_commands("mkdir -p /var/www/munin ; chown munin:munin /var/www/munin", options)
    Shell::execute_shell_commands("sudo a2enmod fcgid", options)
    # /etc/munin/apache.conf:
    #  Alias /munin /var/www/munin
    #  <Directory /var/www/munin ...
    # etc
    Shell::execute_shell_commands("service apache2 restart", options)
    Shell::execute_shell_commands("service munin-node restart", options)
    # restart apache2 ; restart munin-node
  end

  def self.message(options, message)
    puts("#{File.basename(__FILE__)}: #{message}") if options.verbose?()
  end

end # end of InstallMuninMaster

# Test cases
if __FILE__ == $0
  require "Installer.rb"
  ARGV.clear()
  ARGV << "--dry-run"
  ARGV << "--verbose"
  options = Installer::parse_options()
  puts("# Install munin master (dry run, verbose)")
  InstallMuninMaster::install(options)
  puts("# Configure munin master (dry run, verbose)")
  InstallMuninMaster::configure(options)
end

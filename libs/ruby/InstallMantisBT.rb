#!/usr/bin/env ruby

require "pathname.rb"
$LOAD_PATH.unshift(Pathname.new(__FILE__).realpath().dirname().dirname().dirname() + "libs" + "ruby")

require "Package.rb"

require "socket.rb"

module InstallMantisBT
  
  MANTIS_BT = "mantisbt-1.2.19"
  
  def self.install(options)
    shell_options = []
    shell_options << :dry_run if options.dry_run?()

    # Download the mantisbt package and unpack it in the www tree.
    Shell::execute_shell_commands("cd /tmp; wget -nv  wget http://downloads.sourceforge.net/project/mantisbt/mantis-stable/1.2.19/#{MANTIS_BT}.tar.gz", shell_options)
    Shell::execute_shell_commands("cd /var/www; tar xzvf /tmp/#{MANTIS_BT}.tar.gz", shell_options)
    Shell::execute_shell_commands("mv /var/www/#{MANTIS_BT} /var/www/mantis/", shell_options)
    Shell::execute_shell_commands("chmod -R root:root /var/www/mantis/", shell_options)
  end
  
  def self.configure(options)
    # TODO - manual mysql configuration
    # mysql -u root -p
    # mysql> create database mantisDB;
    # mysql> grant all on mantisDB.* to mantis@localhost identified by 'MySecurePassword';
    # mysql> flush privileges;
    hostname = Socket.gethostbyname(Socket.gethostname()).first()
    puts("To configure MantisBT browse to http://#{hostname}/mantis/admin/install.php")
    puts("Once the configuration is complete, change the administrator password in My Account")
    puts("Afterwards, rename or delete the /var/www/mantis/admin directory.")
  end

  def self.message(options, message)
    puts("#{File.basename(__FILE__)}: #{message}") if options.verbose?()
  end

end # end of InstallMantisBT

# Test cases
if __FILE__ == $0
  require "Installer.rb"
  ARGV.clear()
  ARGV << "--dry-run"
  ARGV << "--verbose"
  options = Installer::parse_options()
  puts("# Install MantisBT (dry run, verbose)")
  InstallMantisBT::install(options)
  puts("# Configure MantisBT (dry run, verbose)")
  InstallMantisBT::configure(options)
end

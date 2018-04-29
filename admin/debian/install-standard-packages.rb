#!/usr/bin/ruby -w

require "pathname.rb"
$LOAD_PATH.unshift(Pathname.new(__FILE__).realpath().dirname().dirname().dirname() + "libs" + "ruby")

require "InstallDnsServer.rb"
require "Installer.rb"
require "InstallMinimalSystem.rb"
require "InstallMantisBT.rb"
require "InstallMuninMaster.rb"
require "InstallNisServer.rb"
require "InstallWebServer.rb"
require "Package.rb"

require 'getoptlong'

def main()
  #+
  # --all
  #    Install and configure all software
  #
  # --workstation
  #    Suitable for a machine like shrugged
  #
  # --server[=nis,dns,web,wiki]
  #    NIS server, DNS server, Web server etc.
  #
  # --development
  #    Build environment
  #
  # --log
  # --nolog
  #    Logs or doesn't log
  #
  # --bundle=misc.bundle
  #    Specifies where to find a bundle (only allowed if script is not in a git repo)
  #
  # --assume-repo
  #    Assume that the script is being run from a "git repo"-like directory structure.
  #
  # --dry-run
  #    Avoid executing any commands
  #
  # --host
  #    Host name
  #
  # --ipv4-address
  #    IPv4 address
  #
  # --verbose
  #    Turn on verbose mode (currently does nothing)
  #-

  # TODO: Use Installer

  do_workstation = false
  do_development = false
  do_server = false
  do_nis_server = false
  do_web_server = false
  do_dns_server = false
  do_munin_master = false
  do_mantis = false
  do_wiki_server = false
  log_file = nil
  host = nil
  ipv4_address = nil
  bad_option = false
  bundle = nil
  assume_in_repo = false

  installer_options = Installer::parse_options(
    [ '--bundle',          '-b', GetoptLong::REQUIRED_ARGUMENT ],
    [ '--log',             '-l', GetoptLong::OPTIONAL_ARGUMENT ],
    [ '--nolog',           '-L', GetoptLong::NO_ARGUMENT ],
    [ '--all',             '-A', GetoptLong::NO_ARGUMENT ],
    [ '--workstation',     '-W', GetoptLong::NO_ARGUMENT ],
    [ '--development',     '-D', GetoptLong::NO_ARGUMENT ],
    [ '--host',            '-H', GetoptLong::REQUIRED_ARGUMENT ],
    [ '--ipv4-address',    '-4', GetoptLong::REQUIRED_ARGUMENT ],
    [ '--server',          '-S', GetoptLong::OPTIONAL_ARGUMENT]
  ) {
    |opt, arg|
    case opt
    when '--bundle'
      bundle = arg.dup()
    when '--host'
      host = arg.dup()
    when '--ipv4-address'
      ipv4_address = arg.dup()
    when '--all'
      do_workstation = true
      do_development = true
      do_server = true
      do_nis_server = true
      do_dns_server = true
      do_web_server = true
      do_wiki_server = true
      do_mantis = true
    when '--workstation'
      do_workstation = true
    when '--development'
      do_development = true
    when '--server'
      do_server = true
      arg.downcase().split(",").each() {
        |server|
        case server
        when 'dns'
          do_dns_server = true
        when 'mantis'
          do_mantis = true
        when 'munin'
          do_munin_master = true
        when 'nis'
          do_nis_server = true
        when 'web'
          do_web_server = true
        when 'wiki'
          do_wiki_server = true
        end
      }
    when '--log'
      if arg.nil?()
        log_file = File.basename($0)
      else
        log_file = arg
      end
    when '--nolog'
      log_file = nil
    when '--assume-in-repo'
      assume_in_repo = true
    else
      $stderr.puts("Unrecognised option: [#{opt}]")
      bad_option = true
    end
  }

  exit(1) if bad_option

  unless assume_in_repo
    # Check if in git repo
    if script_in_git_repo?()
      puts("Running in a git repo") 
      unless bundle.nil?()
        $stderr.puts("--bundle not allowed if running in a git repo")
        exit(2)
      end
    else
      puts("NOT running in a git repo") 
      # Not running in a git repo. Use --bundle to create a repo in $HOME/repo/misc.
      have_git = git_present?()
      if bundle.nil?() || !have_git
        $stderr.puts("Bare script needs a --bundle") if bundle.nil?()
        $stderr.puts("git needs to be installed") if bundle.nil?()
        exit(3)
      end
      # Expand bundle ...
      _, _, status = Shell::execute_shell_commands("mkdir -p $HOME/repo; cd $HOME/repo; git clone #{bundle}")
      unless status
        $stderr.puts("Failed to create repo in root's home directory")
        exit(4)
      end
    end
  end

  actions = Actions.new(log_file, installer_options.dry_run?())
  
  actions.set_host(host)
  actions.set_ipv4_address(ipv4_address)

  #+
  # Prepare a set of actions (things to do)
  #-
  prepare_debian(actions)
  prepare_workstation(actions)      if do_workstation
  prepare_development(actions)      if do_development
  prepare_dns_server(actions)       if do_dns_server
  prepare_munin_master(actions)     if do_munin_master
  prepare_nis_server(actions)       if do_nis_server
  prepare_web_server(actions)       if do_web_server
  prepare_wiki_server(actions)      if do_wiki_server
  prepare_mantis(actions)           if do_mantis
  
  # select-editor?

  # Go through all the configuration functions, one by one.
  actions.config_functions().each() {
    |cf|
    puts("Invoking: #{cf}")
    send(cf, actions)
  }
  
  # All done. Close the log.
  actions.close_log()
end

#+
# Actions class holds a set of context information regarding what needs to be done.
#-

# Note: inheriting from Installer::Options is not the right thing to do and needs to be fixed. TODO.
class Actions < Installer::Options

  attr_reader :apt_packages
  attr_reader :apt_preseed_packages
  attr_reader :config_functions
  attr_reader :dpkg_packages
  attr_reader :host
  attr_reader :ipv4_address

  def initialize(log_file, dry_run)
    super()
    @apt_packages = []
    @apt_preseed_packages = []
    @dpkg_packages = []
    @log = log_file.nil?() ? nil : File.open(log_file, "w")
    puts("Logging to #{log_file}") unless @log.nil?()
    @config_functions = []
    @host = nil
    @ipv4_address = nil
    @dry_run = dry_run
  end

  def dry_run?()
    return @dry_run
  end

  def log(message)
    if message.respond_to?(:each)
      message.each() { |m| @log.write(m) }
    else
      @log.write(message)
    end
  end
  
  def close_log()
    @log.close() unless @log.nil?()
  end
  
  def add_single_apt_package(package)
    @apt_packages << package unless @apt_packages.include?(package)
  end

  def add_apt_packages(packages)
    if packages.respond_to?(:each)
      packages.each() { |pkg| add_single_apt_package(pkg) }
    else
      add_single_apt_package(packages)
    end
  end

  def add_apt_preseed_package(package, question, question_type, value)
    @apt_preseed_packages << "#{package} #{question} #{question_type} #{value}"
  end

  def add_single_dpkg_package(package)
    @dpkg_packages << package unless @dpkg_packages.include?(package)
  end

  def add_dpkg_packages(packages)
    if packages.respond_to?(:each)
      packages.each() { |pkg| add_single_dpkg_package(pkg) }
    else
      add_single_dpkg_package(packages)
    end
  end

  def add_config_function(function)
    @config_functions << function unless @config_functions.include?(function)
  end

  def set_host(host)
    @host = host
  end

  def set_ipv4_address(ipv4_address)
    @ipv4_address = ipv4_address
  end
end

# virt-what needs to be installed early so that VMware can be spotted
def install_virt_what()
  `which virt-what > /dev/nul`
  return if $?.success?()
  Package::install_apt_packages("virt-what", [:dry_run])
end

# Determine whether the script is running out of a git repo
def script_in_git_repo?()
  script_dir = File.basename(__FILE__)
  _, _, status = Shell::execute_shell_commands("cd #{script_dir}; git rev-parse", [:silent_command, :suppress_output])
  return status
end

# Determine whether git is available
def git_present?()
  _, _, status = Shell::execute_shell_commands("which git", [:silent_command, :suppress_output])
  return status
end

# Takes actions to block adverts, such as tweaking the hosts file
def prepare_advert_blocking(actions)
  actions.add_apt_packages("lynx")
  actions.add_config_function(:configure_advert_blocking)
end

def prepare_debian(actions)
  InstallMinimalSystem::install(actions)
  actions.add_config_function(:configure_debian)
end

def prepare_development(actions)
  # Nothing to do here yet
end

def prepare_dns_server(actions)
  InstallDnsServer::install(actions)
  actions.add_config_function(:configure_dns_server)
end

def prepare_japanese_language_support(actions)
  apt = []
  apt << "ibus"
  apt << "ibus-anthy"
  actions.add_apt_packages(apt)
  actions.add_config_function(:configure_japanese_language_support)
end

def prepare_mantis(actions)
  InstallMantisBT::install(actions)
  actions.add_config_function(:configure_mantis)
end

def prepare_munin_master(actions)
  InstallMuninMaster::install(actions)
  actions.add_config_function(:configure_munin_master)
end

def prepare_nis_server(actions)
  InstallNisServer::install(actions)
  actions.add_config_function(:configure_nis_server)
end

def prepare_mysql(actions)
  actions.add_apt_packages("mysql-server")
end

def prepare_vmware_tools(actions)
  install_virt_what()
  out, _, _ = Shell::execute_shell_commands("virt-what", [:silent_command, :suppress_output])
  return unless out =~ /vmware/ix
  # This should only do something if running in a vmware environment
  # ?
end

def prepare_web_server(actions)
  InstallWebServer::install(actions)
end

def prepare_wiki_server(actions)
  # ?
end

def prepare_workstation(actions)

  InstalLWorkstation::install(actions)

end

def configure_advert_blocking(actions)
  puts("Performing: #{__method__}")
  return if actions.dry_run?()
  path = File.path(File.dirname(__FILE__))
  Shell::execute_shell_commands("#{path}/install-advert-blocking-hosts-file.sh")
end

def configure_debian(actions)
  InstallMinimalSystem::configure(actions, actions.host(), true)
end

def configure_dns_server(actions)
  puts("Performing: #{__method__} ")
  return if actions.dry_run?()
  InstallDnsServer::configure(actions)
end

def configure_japanese_language_support(actions)
  puts("TODO:#{__method__} ")
  return if actions.dry_run?()
  # Go to Preferences -> Language Support
end

def configure_mantis(actions)
  puts("Performing:#{__method__} ")
  return if actions.dry_run?()
  InstallMantisBT::configure(actions)
end

def configure_munin_master(actions)
  puts("TODO:#{__method__} ")
  return if actions.dry_run?()
  InstallMuninMaster::configure(actions)
end

def configure_nis_server(actions)
  puts("TODO:#{__method__} ")
  return if actions.dry_run?()
  InstallNisServer::configure(actions)
end

def configure_mediawiki(script_dir)
  exec_as_sudo("mysql_install_db")
  exec_as_sudo("mysql_secure_installation")
  exec_as_sudo("wget http://download.wikimedia.org/mediawiki/1.16/mediawiki-1.16.4.tar.gz")
  exec_as_sudo("cd ~/tmp; tar -xzvf #{script_dir}mediawiki-1.16.4.tar.gz")
  exec_as_sudo("mkdir /var/www/mediawiki")
  exec_as_sudo("cp -r ~/tmp/mediawiki-1.16.4/* /var/www/mediawiki")
  # sudo vi /etc/apache2/apache2.conf
  # AddType application/x-httpd-php .html
  sql_filename = "/home/antonioc/tmp/sql.tmp"
  File.open(sql_filename, "w") {
    |f|
    f.puts("CREATE DATABASE mediawiki;")
    f.puts("CREATE USER mediawikiuser;")
    f.puts("SET PASSWORD FOR mediawikiuser = PASSWORD('mywiki');")
    f.puts("GRANT ALL PRIVILEGES ON mediawiki.* TO mediawikiuser IDENTIFIED BY 'mywiki';")
  }
  exec_as_sudo("mysql -u root -pmysql -u root -pharold < #{sql_filename}")
  exec_as_sudo("chmod a+w /var/www/mediawiki/config/")
  # navigate to http://127.0.0.1/mediawiki and fill in the form
  # sudo mv /var/www/mediawiki/config/LocalSettings.php /var/www/mediawiki


end

# Invoke the main function, otherwise nothing happens!
main()

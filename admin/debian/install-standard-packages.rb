#!/usr/bin/ruby -w

require "pathname.rb"

MISC_DIR = Pathname.new(__FILE__).realpath().dirname().dirname().dirname()
$LOAD_PATH.unshift(MISC_DIR + "libs" + "ruby")

require 'getoptlong'

require "Package.rb"

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
  #-

  options = GetoptLong.new(
    [ '--dry-run',         '-n', GetoptLong::NO_ARGUMENT ],
    [ '--bundle',          '-b', GetoptLong::REQUIRED_ARGUMENT ],
    [ '--log',             '-l', GetoptLong::OPTIONAL_ARGUMENT ],
    [ '--nolog',           '-L', GetoptLong::NO_ARGUMENT ],
    [ '--all',             '-a', GetoptLong::NO_ARGUMENT ],
    [ '--workstation',     '-w', GetoptLong::NO_ARGUMENT ],
    [ '--development',     '-d', GetoptLong::NO_ARGUMENT ],
    [ '--host',            '-h', GetoptLong::REQUIRED_ARGUMENT ],
    [ '--ipv4-address',    '-4', GetoptLong::REQUIRED_ARGUMENT ],
    [ '--server',          '-s', GetoptLong::OPTIONAL_ARGUMENT]
  )

  do_workstation = false
  do_development = false
  do_server = false
  do_nis_server = false
  do_web_server = false
  do_dns_server = false
  do_wiki_server = false
  log_file = nil
  dry_run = false
  host = nil
  ipv4_address = nil
  bad_option = false

  bundle = nil
  assume_in_repo = false

  options.each() {
    |opt, arg|
    case opt
    when '--dry-run'
      dry_run = true
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
    when '--workstation'
      do_workstation = true
    when '--development'
      do_development = true
    when '--server'
      do_server = true
      arg.downcase().split(",").each() {
        |server|
        case server
        when 'nis'
          do_nis_server = true
        when 'dns'
          do_dns_server = true
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

  actions = Actions.new(log_file, dry_run)

  actions.set_host(host)
  actions.set_ipv4_address(ipv4_address)

  #+
  # Prepare a set of actions (things to do)
  #-
  prepare_debian(actions)
  prepare_workstation(actions)      if do_workstation
  prepare_development(actions)      if do_development
  prepare_dns_server(actions)       if do_dns_server
  prepare_nis_server(actions)       if do_nis_server
  prepare_web_server(actions)       if do_web_server
  prepare_wiki_server(actions)      if do_wiki_server

  # Install the necessary packages via apt
  apt_options = []
  apt_options << :dry_run if dry_run
  Package::install_apt_packages(actions.apt_packages(), apt_options)

  # Install packages that need presseding
  apt_options = []
  apt_options << :dry_run if dry_run
  Package::install_apt_preseed_packages(actions.apt_preseed_packages(), apt_options)

  # Install the necessary packages via dpkg
  dpkg_options = []
  dpkg_options << :dry_run if dry_run
  Package::install_dpkg_packages(actions.dpkg_packages(), dpkg_options)

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
class Actions

  attr_reader :apt_packages
  attr_reader :apt_preseed_packages
  attr_reader :config_functions
  attr_reader :dpkg_packages
  attr_reader :host
  attr_reader :ipv4_address

  def initialize(log_file, dry_run)
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
  apt = []
  apt << "emacs"                     # wheezy has emacs23, jessie has emcs24, so be non-specific here
  apt << "lsb-release"
  apt << "nano"
  apt << "nfs-common"
  apt << "nfs-kernel-server"
  apt << "portmap"
  apt << "sudo"
  actions.add_apt_preseed_package("nis", "nis/domain", "string", "flexbl")
  actions.add_apt_packages(apt)
  actions.add_config_function(:configure_hostname)
  actions.add_config_function(:configure_ip_address)
  actions.add_config_function(:configure_nis_client)
  actions.add_config_function(:configure_sudo)
end

def prepare_development(actions)
  # Nothing to do here yet
end

def prepare_dns_server(actions)
  apt = []
  apt << "bind9"
  apt << "dnsutils"
  actions.add_apt_packages(apt)
  actions.add_config_function(:configure_dns_server)
end

def prepare_japanese_language_support(actions)
  apt = []
  apt << "ibus"
  apt << "ibus-anthy"
  actions.add_apt_packages(apt)
  actions.add_config_function(:configure_japanese_language_support)
end

def prepare_nis_server(actions)
  apt = []
  apt << "nis"
  apt << "portmap"
  actions.add_apt_packages(apt)
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
  prepare_mysql(actions)
  apt = []
  apt << "apache2"
  apt << "apache2-doc"
  apt << "apache2-utils"
  apt << "php5"
  apt << "php5-mysql"
  actions.add_apt_packages(apt)
end

def prepare_wiki_server(actions)
  # ?
end

def prepare_workstation(actions)
  apt = []
  # apt << "knode"                   # not available on jessie (at least not on arm64)
  apt << "dovecot-imapd"
  apt << "dovecot-pop3d"
  apt << "emacs"                     # wheezy has emacs23, jessie has emcs24, so be non-specific here
  apt << "gconf-editor"
  apt << "git-core"
  apt << "git-doc"
  apt << "keepassx"
  apt << "lame"                      # needed by anki
  apt << "mercurial"
  apt << "ntp"
  apt << "python-sqlalchemy"         # needed by anki
  apt << "rdesktop"

  actions.add_apt_packages(apt)

  dpkg_packages = []
  dpkg_packages << "anki"
  dpkg_packages << "google-chrome"
  actions.add_dpkg_packages(apt)
  
  prepare_web_server(actions)
  prepare_mysql(actions)
  prepare_vmware_tools(actions)
  prepare_wiki_server(actions)
  prepare_japanese_language_support(actions)
  prepare_advert_blocking(actions)
end

def configure_advert_blocking(actions)
  puts("Performing: #{__method__}")
  return if actions.dry_run?()
  path = File.path(File.dirname(__FILE__))
  Shell::execute_shell_commands("#{path}/install-advert-blocking-hosts-file.sh")
end

def configure_dns_server(actions)
  puts("TODO:#{__method__} ")
  return if actions.dry_run?()
  # Configure the zone file /etc/bind/zones/master/flexbl.local as follows:
  # Configure the reverse mapping /etc/bind/zones/master/192.168.1.rev as follows:
  # Point bind9 at the zone file by editing /etc/bind/named.conf.local:
end

def configure_hostname(actions)
  puts("Performing :#{__method__}")
  return if actions.dry_run?()
  host = actions.host()
  if host.nil?()
    puts("No host name configuration required")
    return
  end

  # Set up the require /etc/hostname file
  File.open("/etc/hostname", "w") { |file| file.write("#{host}\n") }

  # Edit the existing /etc/hosts file to change the current host to the new one
  Shell::execute_shell_commands("cp /etc/hosts /etc/hosts.original; cat /etc/hosts.original | sed -e 's/127.0.1.1.*/127.0.1.1       #{host}/' > /etc/hosts")
end

def configure_ip_address(actions)
  puts("TODO:#{__method__} ")
  return if actions.dry_run?()
  # Set a new IP address if required
  this_ip = actions.ipv4_address()
  return if this_ip.nil?()
  dns_master = "192.168.1.105"
  gateway = "192.168.1.101"
  File.open("/etc/network/interfaces", "w") {
    |file|
    file.write("# interfaces(5) file used by ifup(8) and ifdown(8)\n\n")
    file.write("auto lo\n")
    file.write("iface lo inet loopback\n\n")
    file.write("auto eth0\n")
    file.write("iface eth0 inet static\n")
    file.write("  address #{this_ip}\n")
    file.write("  netmask 255.255.255.0\n")
    file.write("  gateway #{gateway}\n")
    file.write("  dns-nameservers #{dns_master} 8.8.8.8\n")
    file.write("  dns-search flexbl.co.uk\n\n\n")
  }
end

def configure_japanese_language_support(actions)
  puts("TODO:#{__method__} ")
  return if actions.dry_run?()
  # Go to Preferences -> Language Support
end

def configure_nis_client(actions)
  puts("Processing:#{__method__} ")
  return if actions.dry_run?()
  Shell::execute_shell_commands("domainname flexbl")
end

def configure_nis_server(actions)
  puts("TODO:#{__method__} ")
  return if actions.dry_run?()
  # Edit /etc/default/nis and change the NISMASTER line to
  # NISSERVER=master
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

def configure_sudo(actions)
  puts("TODO:#{__method__} ")
  return if actions.dry_run?()
  #setup sudo
  #sudo select-editor
  #sudo visudo
  #add this line: $USER ALL=(ALL:ALL) NOPASSWD: ALL
end


# TODO: consider VMTools?
# report time taken for each install and success/failure
# support various options (shrugged, HDS-VPN, testing)

# configure NIS server
# configure NIS client

def install_vmtools()
  puts("VMware Tools installer not yet implemented.")
  # Need the virt-what tool to decide whether this is vmware or not
  if 'virt-what' != "vmware"
    puts("Not running under VMware")
    return
  end
=begin
# persuade the CD to mount ...                                                                             
use mount to find out what has /dev/sr0 mounted and unmount it
mkdir tmp                                                                                                  
cd tmp                                                                                                     
tar zxvf /media/antonioc/VMware\ Tools\VMWareTools-9.2.2-893683.tar.gz                                     
cd vmware-tools-distrib                                                                                    
sudo ./vmware-install.pl -d
=end
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

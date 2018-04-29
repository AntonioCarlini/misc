#!/usr/bin/ruby -w

require "pathname.rb"
$LOAD_PATH.unshift(Pathname.new(__FILE__).realpath().dirname().dirname().dirname() + "libs" + "ruby")

require "InstallHostnameAndAddress.rb"
require "InstallNisClient.rb"

module InstallMinimalSystem
  
  def self.install(installer_options)
    apt_options = []
    apt_options << :dry_run if installer_options.dry_run?()

    apt_packages = []
    apt_packages << "emacs"                     # wheezy has emacs23, jessie has emcs24, so be non-specific here
    apt_packages << "lsb-release"
    apt_packages << "munin-node"
    apt_packages << "nano"
    apt_packages << "nfs-common"
    apt_packages << "nfs-kernel-server"
    apt_packages << "ntp"
    apt_packages << "openssh-server"
    apt_packages << "portmap"
    apt_packages << "sudo"

    # Install the necessary packages via apt
    message(installer_options, "Installing apt packages")
    Package::install_apt_packages(apt_packages, apt_options)

    # nis needs special handling to avoid a hang waiting for input
    message(installer_options, "Installing nis-client")
    InstallNisClient::install(installer_options)
  end
  
  def self.configure(installer_options, hostname, do_ipv4)
    shell_options = []
    shell_options << :dry_run if installer_options.dry_run?()

    do_host = !hostname.nil?() && !hostname.empty?()
    message(installer_options, "Configure host name") if installer_options.verbose?() && do_host
    InstallHostnameAndAddress::configure(installer_options, hostname) if do_host

    message(installer_options, "Configure nis client")
    InstallNisClient::configure(installer_options)

    message(installer_options, "Configure sudo")
    # actions.add_config_function(:configure_sudo)
    # setup sudo
    # sudo select-editor
    # sudo visudo
    # add this line: $USER ALL=(ALL:ALL) NOPASSWD: ALL
    # /etc/ssh/sshd_config
    # PermitRootLogin: no
    message(installer_options, "Configure timezone")
    Shell::execute_shell_commands("cp /usr/share/zoneinfo/Europe/London /etc/localtime", shell_options)
  end

  def self.message(installer_options, message)
    puts("#{File.basename(__FILE__)}: #{message}") if installer_options.verbose?()
  end

end # end of InstallMinimalSystem

# Test cases
if __FILE__ == $0
  require "Installer.rb"
  ARGV.clear()
  ARGV << "--dry-run"
  ARGV << "--verbose"
  host = "flexpc"
  installer_options = Installer::parse_options()
  puts("# Install minimal systemt (dry run, verbose) specifying host #{host} and setting an IPv4 address")
  InstallMinimalSystem::install(installer_options)
  InstallMinimalSystem::configure(installer_options, host, true)
end

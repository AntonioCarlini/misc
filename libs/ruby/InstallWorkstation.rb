#!/usr/bin/env ruby

require "pathname.rb"
$LOAD_PATH.unshift(Pathname.new(__FILE__).realpath().dirname().dirname().dirname() + "libs" + "ruby")

require "InstallAdvertBlocking.rb"
require "InstallWebServer.rb"
require "Package.rb"

module InstallWorkstation
  
  def self.install(installer_options)
    apt_options = []
    apt_options << :dry_run if installer_options.dry_run?()

    apt = []
    # apt << "knode"                   # not available on jessie (at least not on arm64)
    apt << "ack-grep"
    apt << "dovecot-imapd"
    apt << "dovecot-pop3d"
    apt << "emacs"                     # wheezy has emacs23, jessie has emcs24, so be non-specific here
    apt << "gconf-editor"
    apt << "git-core"
    apt << "git-doc"
    apt << "keepassx"
    apt << "lame"                      # needed by anki
    apt << "mercurial"
    apt << "mysql-server"
    apt << "ntp"
    apt << "python-sqlalchemy"         # needed by anki
    apt << "rdesktop"

    InstallAdvertBlocking::install(installer_options)
    InstallWebServer::install(installer_options)

    # TODO: prepare_vmware_tools(actions)
    # TODO: prepare_japanese_language_support(actions)
    
    # Install the necessary packages via apt
    message(installer_options, "Installing apt packages")
    Package::install_apt_packages(apt_packages, apt_options)

    dpkg_options = []
    dpkg_options << :dry_run if installer_options.dry_run?()

    dpkg_packages = []
    dpkg_packages << "anki"
    dpkg_packages << "google-chrome"

    # Install the necessary packages via dpkg
    message(installer_options, "Installing apt packages")
    Package::install_dpkg_packages(dpg_packages, dpkg_options)
  end
  
  def self.configure(installer_options)
    shell_options = []
    shell_options << :dry_run if installer_options.dry_run?()

    
    InstallAdvertBlocking::install(installer_options)
    InstallWebServer::configure(installer_options)

    # TODO: prepare_vmware_tools(actions)
    # TODO: prepare_wiki_server(actions)
    # TODO: prepare_japanese_language_support(actions)

    # Rename the ack-grep command to the shorter "ack"
    Shell::execute_shell_commands("dpkg-divert --local --divert /usr/bin/ack --rename --add /usr/bin/ack-grep", shell_options)
  end

  def self.message(installer_options, message)
    puts("#{File.basename(__FILE__)}: #{message}") if installer_options.verbose?()
  end

end # end of InstallWorkstation

# Test cases
if __FILE__ == $0
  require "Installer.rb"
  ARGV.clear()
  ARGV << "--dry-run"
  ARGV << "--verbose"
  installer_options = Installer::parse_options()
  puts("# Install workstation (dry run, verbose)")
  InstallWorkstation::install(installer_options)
  puts("# Configure workstation (dry run, verbose)")
  InstallWorkstation::configure(installer_options)
end

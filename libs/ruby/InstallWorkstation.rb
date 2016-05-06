#!/usr/bin/env ruby

require "pathname.rb"
$LOAD_PATH.unshift(Pathname.new(__FILE__).realpath().dirname().dirname().dirname() + "libs" + "ruby")

require "InstallAdvertBlocking.rb"
require "InstallWebServer.rb"
require "Package.rb"

module InstallWorkstation
  
  def self.install(options)
    apt_options = []
    apt_options << :dry_run if options.dry_run?()

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
    apt << "mysql-server"
    apt << "ntp"
    apt << "python-sqlalchemy"         # needed by anki
    apt << "rdesktop"

    InstallAdvertBlocking::install(options)
    InstallWebServer::install(options)
    # prepare_web_server(actions)
    # prepare_vmware_tools(actions)
    # prepare_wiki_server(actions)
    # prepare_japanese_language_support(actions)
    
    # Install the necessary packages via apt
    message(options, "Installing apt packages")
    Package::install_apt_packages(apt_packages, apt_options)

    dpkg_options = []
    dpkg_options << :dry_run if options.dry_run?()

    dpkg_packages = []
    dpkg_packages << "anki"
    dpkg_packages << "google-chrome"

    # Install the necessary packages via dpkg
    message(options, "Installing apt packages")
    Package::install_dpkg_packages(dpg_packages, dpkg_options)
  end
  
  def self.configure(options)
    shell_options = []
    shell_options << :dry_run if options.dry_run?()

    InstallAdvertBlocking::install(options)
    InstallWebServer::configure(options)

    # prepare_vmware_tools(actions)
    # prepare_wiki_server(actions)
    # prepare_japanese_language_support(actions)
  end

  def self.message(options, message)
    puts("#{File.basename(__FILE__)}: #{message}") if options.verbose?()
  end

end # end of InstallWorkstation

# Test cases
if __FILE__ == $0
  require "Installer.rb"
  ARGV.clear()
  ARGV << "--dry-run"
  ARGV << "--verbose"
  options = Installer::parse_options()
  puts("# Install workstation (dry run, verbose)")
  InstallWorkstation::install(options)
  puts("# Configure workstation (dry run, verbose)")
  InstallWorkstation::configure(options)
end

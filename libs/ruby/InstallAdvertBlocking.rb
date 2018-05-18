#!/usr/bin/env ruby

require "pathname.rb"
$LOAD_PATH.unshift(Pathname.new(__FILE__).realpath().dirname().dirname().dirname() + "libs" + "ruby")

require "Package.rb"
require "Shell.rb"

require "fileutils.rb"

module InstallAdvertBlocking

  HERALD="Perform all edits BEFORE this line otherwise they will be automatically removed."
  HOSTS="/etc/hosts"
  HOSTS_ADVERT_BLOCK="/tmp/hosts.advert-block"
  
  def self.install(installer_options)
    apt_options = []
    apt_options << :dry_run if installer_options.dry_run?()

    apt_packages = []
    apt_packages << "lynx"

    # Install the necessary packages via apt
    message(installer_options, "Installing apt packages")
    Package::install_apt_packages(apt_packages, apt_options)
  end
  
  def self.configure(installer_options)
    shell_options = []
    shell_options << :dry_run if installer_options.dry_run?()

    file_options = {}
    file_options[:verbose] = true if options.verbose?()
    file_options[:noop] = true if options.dry_run?()
    message(installer_options, "Writing herald")

    message(installer_options, "Copying hosts file and building new header")
    FileUtils.cp(HOSTS, "#{HOSTS}.original", file_options)
    File.open(HOSTS_ADVERT_BLOCK, "w") {
      |advblk|
      File.readlines(HOSTS).each() {
        |line|
        break if line =~ /#{HERALD}/i
        advblk.write(line)
      }
      advblk.write("# #{HERALD}\n\n")
    }
    message(installer_options, "Fetching hosts file addition")
    # Notes:
    # -width=255 is needed otherwise lines are wrapped after 80 characters.
    # Browsing to somonewhocares.org with https fails.
    cmd = "lynx -dump -nolist -width=255 http://someonewhocares.org/hosts/ | sed -n -E -e '/Dan Pollock/,$ p' | sed -e '/[[:digit:]]\\{4\\} top$/Q' >> #{HOSTS_ADVERT_BLOCK}"
    Shell::execute_shell_commands(cmd, shell_options)
    message(installer_options, "Building new hosts file")
    FileUtils.mv(HOSTS_ADVERT_BLOCK, HOSTS, file_options)
  end

  def self.message(installer_options, message)
    puts("#{File.basename(__FILE__)}: #{message}") if installer_options.verbose?()
  end

end # end of InstallAdvertBlocking

# Test cases
if __FILE__ == $0
  require "InstallerOptions.rb"
  ARGV.clear()
  ARGV << "--dry-run"
  ARGV << "--verbose"
  installer_options = Installer::parse_options()
  puts("# Install advert blocking (dry run, verbose)")
  InstallAdvertBlocking::install(installer_options)
  InstallAdvertBlocking::configure(installer_options)
end


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
  
  def self.install(options)
    apt_options = []
    apt_options << :dry_run if options.dry_run?()

    apt_packages = []
    apt_packages << "lynx"

    # Install the necessary packages via apt
    message(options, "Installing apt packages")
    Package::install_apt_packages(apt_packages, apt_options)
  end
  
  def self.configure(options)
    shell_options = []
    shell_options << :dry_run if options.dry_run?()

    file_options = {}
    file_options[:verbose] = true if options.verbose?()
    file_options[:noop] = true if options.dry_run?()
    message(options, "Writing herald")

    message(options, "Copying hosts file and building new header")
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
    message(options, "Fetching hosts file addition")
    # Notes:
    # -width=255 is needed otherwise lines are wrapped after 80 characters.
    cmd = "lynx -dump -nolist -width=255 http://someonewhocares.org/hosts/ | sed -n -E -e '/Dan Pollock/,$ p' | sed -e '/[[:digit:]]\\{4\\} top$/Q' >> #{HOSTS_ADVERT_BLOCK}"
    Shell::execute_shell_commands(cmd, shell_options)
    message(options, "Building new hosts file")
    FileUtils.mv(HOSTS_ADVERT_BLOCK, HOSTS, file_options)
  end

  def self.message(options, message)
    puts("#{File.basename(__FILE__)}: #{message}") if options.verbose?()
  end

end # end of InstallAdvertBlocking

# Test cases
if __FILE__ == $0
  require "Installer.rb"
  ARGV.clear()
  ARGV << "--dry-run"
  ARGV << "--verbose"
  host = "flexpc"
  options = Installer::parse_options()
  puts("# Install advert blocking (dry run, verbose)")
  InstallAdvertBlocking::install(options)
  InstallAdvertBlocking::configure(options)
end


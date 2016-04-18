#!/usr/bin/env ruby

require "pathname.rb"

MISC_DIR = Pathname.new(__FILE__).realpath().dirname().dirname().dirname()
$LOAD_PATH.unshift(MISC_DIR + "libs" + "ruby")

require "Configuration.rb"
require "Installer.rb"
require "Package.rb"

options = Installer::parse_options()

domain = Configuration::get_value("nis-domain")
apt_options = []
apt_options << :dry_run if options.dry_run?()

# Install the nis package silently by preseeding the required values.
Package::install_apt_preseed_packages("nis nis/domain string #{domain}", apt_options)

# Ensure that the required domain name is set
Shell::execute_shell_commands("domainname #{domain}", apt_options)

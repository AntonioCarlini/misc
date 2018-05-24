#!/usr/bin/env ruby

require "pathname.rb"
$LOAD_PATH.unshift(Pathname.new(__FILE__).realpath().dirname().dirname().dirname())

require "libs/ruby/InstallerOptions.rb"
require "libs/ruby/InstallMySQL.rb"

installer_options = Installer::parse_options()

InstallMySQL::install(installer_options) if installer_options.install?()
InstallMySQL::configure(installer_options) if installer_options.configure?()

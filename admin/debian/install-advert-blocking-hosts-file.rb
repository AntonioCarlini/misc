#!/usr/bin/env ruby

require "pathname.rb"
$LOAD_PATH.unshift(Pathname.new(__FILE__).realpath().dirname().dirname().dirname() + "libs" + "ruby")

require "InstallerOptions.rb"
require "InstallAdvertBlocking.rb"

installer_options = Installer::parse_options()

InstallAdvertBlocking::install(installer_options)
InstallAdvertBlocking::configure(installer_options)

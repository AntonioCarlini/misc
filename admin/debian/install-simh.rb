#!/usr/bin/env ruby

require "pathname.rb"
$LOAD_PATH.unshift(Pathname.new(__FILE__).realpath().dirname().dirname().dirname() + "libs" + "ruby")

require "InstallerOptions.rb"
require "InstallSimh.rb"

installer_options = Installer::parse_options()

InstallSimh::install(installer_options) if installer_options.install?()
InstallSimh::configure(installer_options) if installer_options.configure?()

#!/usr/bin/env ruby

require "pathname.rb"
$LOAD_PATH.unshift(Pathname.new(__FILE__).realpath().dirname().dirname().dirname() + "libs" + "ruby")

require "Installer.rb"
require "InstallNisClient.rb"

installer_options = Installer::parse_options()

InstallNisClient::install(installer_options)
InstallNisClient::configure(installer_options)

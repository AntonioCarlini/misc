#!/usr/bin/env ruby

require "pathname.rb"

MISC_DIR = Pathname.new(__FILE__).realpath().dirname().dirname().dirname()
$LOAD_PATH.unshift(MISC_DIR + "libs" + "ruby")

require "Installer.rb"
require "InstallNisClient.rb"

options = Installer::parse_options()

InstallNisClient::install(options)
InstallNisClient::configure(options)

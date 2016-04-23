#!/usr/bin/env ruby

require "pathname.rb"
$LOAD_PATH.unshift(Pathname.new(__FILE__).realpath().dirname().dirname().dirname() + "libs" + "ruby")

require "Installer.rb"
require "InstallSimh.rb"

options = Installer::parse_options()

InstallSimh::install(options) if options.install?()
InstallSimh::configure(options) if options.configure?()

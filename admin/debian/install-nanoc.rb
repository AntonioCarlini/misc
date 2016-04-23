#!/usr/bin/env ruby

require "pathname.rb"
$LOAD_PATH.unshift(Pathname.new(__FILE__).realpath().dirname().dirname().dirname() + "libs" + "ruby")

require "Installer.rb"
require "Package.rb"

options = Installer::parse_options()

gems = []
# nanoc itself ...
gems << "nanoc"
# ... and the supporting cast
gems << "adfs"
gems << "haml"
gems << "kramdown"

gem_options = []
gem_options << :dry_run if options.dry_run?()

# Install the nis package silently by preseeding the required values.
Package::install_ruby_gems(gems, gem_options)


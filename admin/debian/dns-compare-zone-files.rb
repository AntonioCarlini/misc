#!/usr/bin/env ruby

require "pathname.rb"
$LOAD_PATH.unshift(Pathname.new(__FILE__).realpath().dirname().dirname().dirname() + "libs" + "ruby")

require "DnsZoneFile.rb"

def main()

  # Sanity check the supplied arguments
  exit_code = 0
  
  if ARGV.length() < 2
    usage()
    exit_code = 2
  end

  first = ARGV.shift()
  second = ARGV.shift()

  if !first.nil?() && !File.file?(first)
    $stderr.puts("File #{first} does not exist")
    exit_code = 3 if exit_code == 0
  end

  if !second.nil?() && !File.file?(second)
    $stderr.puts("File #{second} does not exist")
    exit_code = 4 if exit_code == 0
  end

  exit(exit_code) unless exit_code == 0
  
  identical = DnsZoneFile::zone_files_functionally_identical?(first, second)
  if identical
    exit 0
  else
    exit 1
  end
end

def usage()
  $stderr.puts("Usage: #{File.basename(__FILE__)} first-dns-zone-file second-dns-zone-file")
end

# Invoke the main function to kick off processing
main()

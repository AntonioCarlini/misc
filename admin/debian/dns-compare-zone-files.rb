#!/usr/bin/env ruby

require "pathname.rb"
$LOAD_PATH.unshift(Pathname.new(__FILE__).realpath().dirname().dirname().dirname() + "libs" + "ruby")

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
  
  identical = zone_files_functionally_identical?(first, second)
  if identical
    exit 0
  else
    exit 1
  end
end

def usage()
  $stderr.puts("Usage: #{File.basename(__FILE__)} first-dns-zone-file second-dns-zone-file")
end

# Compare the two zone files, ignoring things that don't matter (e.g. whitespace, comments)
# and things that are expected to change (currently only the serial number).
def zone_files_functionally_identical?(first, second)
  error_seen = false
  begin
    first_data = read_zone_file(first)
  rescue
    $stderr.puts("Failed to read #{first}")
    error_seen = true
  end
  begin
    second_data = read_zone_file(second)
  rescue
    $stderr.puts("Failed to read #{second}")
    error_seen = true
  end
  
  return false if error_seen
  
  return first_data == second_data
end

# Read a zone file, but strip out excess whitespace, remove comments and remove the serial number.
# Note that this depends on knowledge of the output format used by dns-build-zone-file.rb.
def read_zone_file(file)
  # Read the file. Zone files are expected to be less than 1MiB in size.
  # Replace multiple spaces with one space.
  # Remove the line that contains the Serial number
  # Remove everything after the first ";" until the end of a line.
  # Remove completely empty lines.
  data = IO.read(file).gsub(/ +/, " ").sub(/^\s*\d+\s*;\s*Serial*$\n/, "").gsub(/;.*/, "").gsub(/^\s*$\n/, "")
  return data
end  

# Invoke the main function to kick off processing
main()

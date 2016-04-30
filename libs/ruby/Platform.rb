#!/usr/bin/ruby -w

$LOAD_PATH.unshift(File.dirname(__FILE__))

require "Shell.rb"

module Platform

  @@os = nil
  @@base = nil
  @@variant = nil

  # Python's platform module has a decent go at working out the platform.
  def self.check_python()
    shell_options = [ :silent_command , :suppress_output ]
    cmd = %Q(python -c "import platform;print(platform.linux_distribution()[0])" 2> /dev/null)
    op, _, status = Shell::execute_shell_commands(cmd, shell_options)
    return status, op.chomp()
  end

  def self.use_python()
    status, op = check_python()
    if status
      case op
      when "raspian" then
        @@os = "Linux"
        @@base = "debian"
        @@version = "raspian"
      when "debian"
        @@os = "Linux"
        @@base = "debian"
        identify_debian_variant()
      else
        @@os ||= "Unknown"
        @@base ||= ""
        @@variant ||= ""
      end
    end
  end

  # "uname -s" provides the base OS type (e.g. Linux)
  def self.check_uname()
    shell_options = [ :silent_command , :suppress_output ]
    cmd = "uname -s"
    op, _, status = Shell::execute_shell_commands(cmd, shell_options)
    return status, op.chomp()
  end

  def self.use_uname()
    status, op = check_uname()
    if status
      case op
      when "Linux" then
        @@os = "Linux"
        # TODO identify Linux variant
      else
        @@os ||= "Unknown"
        @@base ||= ""
        @@variant ||= ""
      end
    end
  end

  # More modern Linux releases supply some information in /etc/os-release
  def self.check_etc_os_release()
    File.foreach("/etc/os-release") {
      |line|
      return true, $1 if line =~ /^ID=(.*)$/
    }
    return false, nil
  end

  def self.use_etc_os_release()
    status, op = check_etc_os_release()
    if status
      case op
      when "Linux" then
        @@os = "Linux"
        # TODO identify Linux variant
      else
        @@os ||= "Unknown"
        @@base ||= nil
        @@variant ||= nil
      end
    end
  end

  # "lsb_release -a" provides a DistributorID
  def self.check_lsb_release
    shell_options = [ :silent_command , :suppress_output, :suppress_errors ]
    cmd = "lsb_release -a"
    op, _, status = Shell::execute_shell_commands(cmd, shell_options)
    if status
      op.each_line() {
      |line|
      return true, $1 if line =~ /^Distributor ID:\s*(.*)$/
      }
    end
    return false, nil
  end

  def self.use_lsb_release()
    status, op = check_lsb_release()
    if status
      case op
      when "Debian" then
        @@os = "Linux"
        @@base = "debian"
        @@variant = "debian"
      when "LinuxMint" then
        @@os = "Linux"
        @@os = "debian"
        @@variant = "LinuxMint"
      else
        @@os ||= "Unknown"
        @@base ||= nil
        @@variant ||= nil
      end
    end
  end

  # If running on debian, try to be more specific
  def self.identify_debian_variant()
    # Start by looking at /etc/os-release
    status, op = check_etc_os_release()
    if status
      @@variant = op
      return
    end
  end

  # Run through all implemented methods of identifying the system until one succeeds.
  # Success is defined as having a non-nil @@variant.
  def self.identify()
    # Start by using python
    use_python()
    return unless @@variant.nil?()

    # Look in /etc/os-release
    use_etc_os_release()
    return unless @@variant.nil?()

    # Fall back to "uname -s"
    use_uname()

  end

  def self.display_dump_entry(type, status, op)
    format_string = "%-20.20s %s"
    if status
      puts(format_string % ["#{type}:", "[#{op}]"])
    else
      puts(format_string % ["#{type}:", "* Failed *"])
    end
  end

  # These are the methods that the module purports to provide.

  # Dump all data sources - useful when seeking to fingerprint a new platform.
  def self.dump()
    status, op = check_python()    
    display_dump_entry("python", status, op)

    status, op = check_etc_os_release()    
    display_dump_entry("/etc/os-release", status, op)

    status, op = check_uname()    
    display_dump_entry("uname", status, op)

    status, op = check_lsb_release()    
    display_dump_entry("lsb_release", status, op)
  end

  def self.get_os()
    return @@os unless @@os.nil?()
    identify() 
    return @@os
  end

  def self.get_base()
    return @@base unless @@base.nil?()
    identify()
    return @@base
  end

  def self.get_variant()
    return @@variant unless @@variant.nil?()
    identify()
    return @@variant
  end
end # end of Platform

# Test cases
if __FILE__ == $0
  puts("#"*80 + "\nFind the OS details:")
  puts("get_os():            [#{Platform::get_os()}]")
  puts("get_base():          [#{Platform::get_base()}]")
  puts("get_variant:         [#{Platform::get_variant()}]")
  puts("\nData dump:\n")
  Platform::dump()
end

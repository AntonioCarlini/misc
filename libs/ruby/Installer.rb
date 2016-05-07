#!/usr/bin/env ruby 

require 'getoptlong'

module Installer
  
  class Options
    def initialize(extra_options = nil)
      reset()
      # If the caller needs additional options to bne recognised, do that here.
      @opts += extra_options unless extra_options.nil?()
    end
    
    def reset()
      @install                    = false
      @configure                  = false
      @dry_run                    = false
      @verbose                    = false

      # standard GetoptLong options
      @opts = []
      @opts << [ '--install',         '-i', GetoptLong::NO_ARGUMENT ]
      @opts << [ '--configure',       '-c', GetoptLong::NO_ARGUMENT ]
      @opts << [ '--dry-run',         '-d', GetoptLong::NO_ARGUMENT ]
      @opts << [ '--verbose',         '-v', GetoptLong::NO_ARGUMENT ]

    end

    def install?()
      return @install
    end

    def configure?()
      return @configure
    end

    def dry_run?()
      return @dry_run
    end

    def verbose?()
      return @verbose
    end

    def parse()

      options = GetoptLong.new(*@opts)
      options.each() {
        |opt, arg|
        case opt
        when '--dry-run'
          @dry_run = true
        when '--install'
          @install = true
        when '--configure'
          @configure = true
        when '--verbose'
          @verbose = true
        else
          # If there is an option that this code doesn't know about, pass it to the caller for handling
          # GetoptLong will raise an exception for a real error.
          yield(opt, arg) if block_given?()
        end
      }

      if !@install && !@configure
        @install = true
        @configure = true
      end

    end
    
  end # end of Installer::Options
  
  # Invokes GetoptLong.
  # Returns a properly initialised Options class.
  def self.parse_options(*extra_options)
    opt = Installer::Options.new(extra_options)
    if block_given?()
      opt.parse(&Proc.new())
    else
      opt.parse()
    end
    return opt
  end

end # end of Installer

# Test cases
if __FILE__ == $0
  p ARGV
  puts("#"*80 + "\nProcess --install")
  ARGV.clear()
  ARGV << "--install"
  options = Installer::parse_options()
  puts("--install:   #{options.install?()}")
  puts("--configure: #{options.configure?()}")
  puts("--dry-run:   #{options.dry_run?()}")
  puts("--verbose:   #{options.verbose?()}")

  puts("#"*80 + "\nProcess --configure")
  ARGV.clear()
  ARGV << "--configure"
  options = Installer::parse_options()
  puts("--install:   #{options.install?()}")
  puts("--configure: #{options.configure?()}")
  puts("--dry-run:   #{options.dry_run?()}")
  puts("--verbose:   #{options.verbose?()}")

  puts("#"*80 + "\nProcess --dry-run")
  ARGV.clear()
  ARGV << "--dry-run"
  options = Installer::parse_options()
  puts("--install:   #{options.install?()}")
  puts("--configure: #{options.configure?()}")
  puts("--dry-run:   #{options.dry_run?()}")
  puts("--verbose:   #{options.verbose?()}")

  puts("#"*80 + "\nProcess --verbose")
  ARGV.clear()
  ARGV << "--verbose"
  options = Installer::parse_options()
  puts("--install:   #{options.install?()}")
  puts("--configure: #{options.configure?()}")
  puts("--dry-run:   #{options.dry_run?()}")
  puts("--verbose:   #{options.verbose?()}")

  puts("#"*80 + "\nProcess --configure --install --dry-run")
  ARGV.clear()
  ARGV << "--dry-run"
  ARGV << "--install"
  ARGV << "--configure"
  options = Installer::parse_options()
  puts("--install:   #{options.install?()}")
  puts("--configure: #{options.configure?()}")
  puts("--dry-run:   #{options.dry_run?()}")
  puts("--verbose:   #{options.verbose?()}")

  puts("#"*80 + "\nProcess --unknown --dry-run")
  ARGV.clear()
  ARGV << "--dry-run"
  ARGV << "--unknown"
  begin
    options = Installer::parse_options()
  rescue GetoptLong::InvalidOption
    $stderr.puts("Saw expected problem with --unknown option")
  else
    puts("--install:   #{options.install?()}")
    puts("--configure: #{options.configure?()}")
    puts("--dry-run:   #{options.dry_run?()}")
    puts("--verbose:   #{options.verbose?()}")
  end

  puts("#"*80 + "\nProcess --extra --install --trailer --dry-run")
  ARGV.clear()
  ARGV << "--extra"
  ARGV << "--install"
  ARGV << "--trailer"
  ARGV << "--dry-run"
  options = Installer::parse_options(
                                     [ '--extra',   '-e', GetoptLong::NO_ARGUMENT ],
                                     [ '--trailer', '-t', GetoptLong::NO_ARGUMENT ]
                                     )
  puts("--install:   #{options.install?()}")
  puts("--configure: #{options.configure?()}")
  puts("--dry-run:   #{options.dry_run?()}")
  puts("--verbose:   #{options.verbose?()}")
end

#!/usr/bin/env ruby 

require 'getoptlong'

module Installer
  
  class Options
    def initialize()
      reset()
      parse()
    end
    
    def reset()
      @install                    = false
      @configure                  = false
      @dry_run                    = false
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

    def parse()
      options = GetoptLong.new(
        [ '--install',         '-i', GetoptLong::NO_ARGUMENT ],
        [ '--configure',       '-c', GetoptLong::NO_ARGUMENT ],
        [ '--dry-run',         '-d', GetoptLong::NO_ARGUMENT ]
      )

      options.each() {
        |opt, arg|
        case opt
        when '--dry-run'
          @dry_run = true
        when '--install'
          @install = true
        when '--configure'
          @configure = true
        else
          $stderr.puts("Unrecognised option: [#{opt}]")
        end
      }

      if !@install && !@configure
        @install = true
        @configure = true
      end
    end
    
  end # end of Installer::Options
  
  def self.parse_options()
    opt = Installer::Options.new()
    return opt
  end

end # end of Installer

# Test cases
if __FILE__ == $0
  puts("#"*80 + "\nProcess --install")
  ARGV.clear()
  ARGV << "--install"
  options = Installer::parse_options()
  puts("--install:   #{options.install?()}")
  puts("--configure: #{options.configure?()}")
  puts("--dry-run:   #{options.dry_run?()}")

  puts("#"*80 + "\nProcess --configure")
  ARGV.clear()
  ARGV << "--configure"
  options = Installer::parse_options()
  puts("--install:   #{options.install?()}")
  puts("--configure: #{options.configure?()}")
  puts("--dry-run:   #{options.dry_run?()}")

  puts("#"*80 + "\nProcess --dry-run")
  ARGV.clear()
  ARGV << "--dry-run"
  options = Installer::parse_options()
  puts("--install:   #{options.install?()}")
  puts("--configure: #{options.configure?()}")
  puts("--dry-run:   #{options.dry_run?()}")

  puts("#"*80 + "\nProcess --configure --install --dry-run")
  ARGV.clear()
  ARGV << "--dry-run"
  ARGV << "--install"
  ARGV << "--configure"
  options = Installer::parse_options()
  puts("--install:   #{options.install?()}")
  puts("--configure: #{options.configure?()}")
  puts("--dry-run:   #{options.dry_run?()}")
end

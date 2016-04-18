#!/usr/bin/ruby -w

$LOAD_PATH.unshift(File.dirname(__FILE__))

require "Shell.rb"

module Package

  class AptOptions
    def initialize(options)
      reset()
      parse(options)
    end
    
    def reset()
      @dry_run                    = false
      @ignore_missing             = true
      @allow_unauthenticated      = false
      @quiet                      = false
      @no_install_recommends      = true
    end

    def parse(options)
      return true if options.nil?() || options.empty?()
      # Parse each option
      options.each() {
        |opt|
        case opt
        when :dry_run                   then @dry_run = true
        when :ignore_missing            then @ignore_missing = true
        when :allow_unauthenticated     then @allow_unauthenticated = true
        when :quiet                     then @quiet = true
        when :no_install_recommends     then @no_install_recommends = true
        else
          return false                  # complain if an unknown option is supplied
        end
      }
      return true
    end

    def text()
      text = ""
      text << "--dry-run "                           if @dry_run
      text << "--ignore-missing "                    if @ignore_missing
      text << "--allow-unauthenticated "             if @allow_unauthenticated
      text << "--quiet "                             if @quiet
      text << "--no-install-recommends "             if @no_install_recommends
      return text
    end
  end

  class DpkgOptions

    def initialize(options)
      reset()
      parse(options)
    end
    
    def reset()
      @dry_run                    = false
    end

    def parse(options)
      return true if options.nil?() || options.empty?()
      # Parse each option
      options.each() {
        |opt|
        case opt
        when :dry_run                   then @dry_run = true
        else
          return false                  # complain if an unknown option is supplied
        end
      }
      return true
    end

    def dry_run?()
      return @dry_run
    end
    
  end

  def self.install_apt_packages(packages, options = nil)
    opt = Package::AptOptions.new(options)
    all_packages = packages.respond_to?(:each) ? packages.join(" ") : packages
    Shell::execute_shell_commands("apt-get -y install #{opt.text()} #{all_packages}")
  end

  def self.install_apt_preseed_packages(packages, options = nil)
    opt = Package::AptOptions.new(options)
    loc_pkg = []
    if packages.respond_to?(:each)
      loc_pkg = packages
    else
      loc_pkg << packages
    end
    loc_pkg.each() {
      |pkg|
      Shell::execute_shell_commands("echo #{pkg} | debconf-set-selections", options)
      Shell::execute_shell_command_with_environment({"DEBIAN_FRONTEND" => "noninteractive"}, "apt-get -y install #{opt.text()} #{pkg.split()[0]}", options)
    }
  end

  def self.install_dpkg_packages(packages, options)
    opt = Package::DpkgOptions.new(options)
    prefix = opt.dry_run?() ? "#" : ""
    if packages.respond_to?(:each)
      packages.each() {
        |p|
        Shell::execute_shell_commands("#{prefix}dpkg -i #{p}")
      }
    else
      Shell::execute_shell_commands("#{prefix}dpkg -i #{packages}")
    end
  end
  
end # end of Package

# Test cases
if __FILE__ == $0
  puts("#"*80 + "\nInstall a single package")
  Package::install_apt_packages("ruby", [:dry_run])
  puts("#"*80 + "\nInstall two packages")
  Package::install_apt_packages(["ruby", "emacs"], [:dry_run])
  puts("#"*80 + "\nInstall one dpkg")
  Package::install_dpkg_packages("ruby", [:dry_run])
  puts("#"*80 + "\nInstall two dpkgs")
  Package::install_dpkg_packages(["ruby", "emacs"], [:dry_run])
end

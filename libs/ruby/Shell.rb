#!/usr/bin/ruby -w

require 'open3'

module Shell
  
  class Options
    def initialize(options)
      reset()
      parse(options)
    end
    
    def reset()
      @stop_on_failure            = false
      @echo_command               = true
      @echo_output                = true
      @combine_out_err            = true
      @dry_run                    = false
      @display_errors             = true
    end

    def stop_on_failure?()
      return @stop_on_failure
    end

    def echo_command?()
      return @echo_command
    end

    def echo_output?()
      return @echo_output
    end

    def combine_out_err?()
      return @combine_out_err
    end

    def dry_run?()
      return @dry_run
    end

    def display_errors?()
      return @display_errors
    end

    def parse(options)
      return true if options.nil?() || options.empty?()
      # Parse each option
      options.each() {
        |opt|
        case opt
        when :stop_on_failure       then @stop_on_failure = true
        when :ignore_failure        then @stop_on_failure = false
        when :echo_command          then @echo_command = true
        when :silent_command        then @echo_command = false
        when :echo_output           then @echo_output = true
        when :suppress_output       then @echo_output = false
        when :combine_out_err       then @combine_out_err = true
        when :split_out_err         then @combine_out_err = false
        when :dry_run               then @dry_run = true
        when :live_run              then @dry_run = false
        when :suppress_errors       then @display_errors = false
        else
          return false                    # complain if an unknown option is supplied
        end
      }
      return true
    end
  end

  def self.execute_single_command(cmd, options)
    status = true
    cum_stdout = ""
    cum_stderr = ""
    puts("$ #{cmd}") if options.echo_command?()
    return "", "", true if options.dry_run?()
    if options.combine_out_err?()
      begin
        Open3.popen2e(cmd) {
          |stdin, stdouterr, thr|
          stdin.close()
          stdouterr.each_line() {
            |line|
            puts("#{line}") if options.echo_output?()
            cum_stdout << line
          }
          status = status && thr.value.success?()
        }
      rescue
        puts("#{cmd.split().first()}: command not found") if options.display_errors?()
        status = false
      end
    else
      begin
        Open3.popen3(cmd) {
          |stdin, stdout, stderr, thr|
          stdin.close()
          stdout.each_line() {
            |line|
            puts("#{line}") if options.echo_output?()
            cum_stdout << line
          }
          stderr.each_line() {
            |line|
            puts("#{line}") if options.echo_output?()
            cum_stderr << line
          }
          status = status && thr.value.success?()
        }
      rescue
        puts("#{cmd.split().first()}: command not found") if options.display_errors?()
        status = false
      end
    end
    return cum_stdout, cum_stderr, status
  end
  
  def self.execute_shell_commands(commands, options = [])
    opt = Shell::Options.new(options)
    cum_stdout = ""
    cum_stderr = ""
    status = true
    if commands.respond_to?(:each)
      commands.each() {
        |cmd|
        cmd_out, cmd_err, cmd_status = self.execute_single_command(cmd, opt)
        cum_stdout << cmd_out
        cum_stderr << cmd_err
        status = status && cmd_status
        if !cmd_status
          return cum_stdout, cum_stderr, false if opt.stop_on_failure?()
        end
      }
    else
      cmd = commands.dup()
      cmd_out, cmd_err, cmd_status = self.execute_single_command(cmd, opt)
      cum_stdout << cmd_out
      cum_stderr << cmd_err
      status = status && cmd_status
      if !cmd_status
        return cum_stdout, cum_stderr, false if opt.stop_on_failure?()
      end
    end
    return cum_stdout, cum_stderr, status
  end

  def self.execute_shell_command_with_environment(environment, command, options = [])
    opt = Shell::Options.new(options)
    status = true
    cum_stdout = ""
    cum_stderr = ""
    puts("$ ENV: #{environment}") if opt.echo_command?()
    puts("$ #{command}") if opt.echo_command?()
    return "", "", true if opt.dry_run?()
    begin
      Open3.popen2e(environment, command) {
        |stdin, stdouterr, thr|
        stdin.close()
        stdouterr.each_line() {
          |line|
            puts("#{line}") # This needs to happen for some reason
            cum_stdout << line
          }
          status = status && thr.value.success?()
        }
    rescue
      puts("#{command.split().first()}: command not found") if options.display_errors?()
      status = false
    end
    return cum_stdout, cum_stderr, status
  end
  
end # end of Shell

# Test cases
if __FILE__ == $0
  puts("# Execute single 'ls'")
  Shell::execute_shell_commands("ls *.rb")
  puts("# Execute series of commands, the second of which fails")
  Shell::execute_shell_commands(["ls *.rb", "xx", "ls foo", "ls -l *.rb"])
  puts("# Execute single 'ls' without echoing the command")
  Shell::execute_shell_commands("ls *.rb", [:silent_command])
  puts("# Execute series of commands, the second of which fails and aborts the execution")
  Shell::execute_shell_commands(["ls *.rb", "xx", "ls foo", "ls -l *.rb"], [ :stop_on_failure ])
end

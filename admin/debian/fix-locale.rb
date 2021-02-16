#!/usr/bin/env ruby

require "pathname.rb"
$LOAD_PATH.unshift(Pathname.new(__FILE__).realpath().dirname().dirname().dirname() + "libs" + "ruby")

require 'getoptlong'

require 'Shell.rb'

ENV_FILE = "/etc/environment"

LINE_1 = "LC_ALL=en_GB.UTF-8"
LINE_2 = "LANG=en_GB.UTF-8\n"

# Parse any arguments

options = GetoptLong.new(
    [ '--dry-run',         '-d', GetoptLong::NO_ARGUMENT ]
  )

dry_run = false
bad_option = false

options.each() {
  |opt, arg|
  case opt
  when '--dry-run'
    dry_run = true
  else
    puts("Unknown option: #{arg}")
    bad_option = true
  end
}

exit(1) if bad_option

# Ensure that /etc/environment contains the required lines

tgt_file = dry_run ? "/dev/null" : ENV_FILE
if File.file?(ENV_FILE)
  env = IO.read(ENV_FILE)
  has_line_1 = env.include?(LINE_1)
  has_line_2 = env.include?(LINE_2)
  File.open(tgt_file, "a") {
    |file|
    file.write("#{LINE_1}\n") unless has_line_1
    file.write("#{LINE_2}\n") unless has_line_2
  } if !has_line_1 || !has_line_2
else
  File.open(tgt_file, "w") {
    |file|
    file.write("#{LINE_1}\n")
    file.write("#{LINE_2}\n")
  }
end

# Tweak /etc/locale.get to uncomment en_GB if required
# Then generate the necessary locales
shell_opt = []
shell_opt << :dry_run if dry_run
Shell::execute_shell_commands("cp /etc/locale.gen /etc/locale.gen.original", shell_opt)
Shell::execute_shell_commands("cat /etc/locale.gen.original | sed -e 's/#.*en_GB/en_GB/' | /etc/locale.gen", shell_opt)
Shell::execute_shell_commands("locale-gen", shell_opt)

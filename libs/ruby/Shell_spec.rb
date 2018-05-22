require "pathname.rb"
$LOAD_PATH.unshift(Pathname.new(__FILE__).realpath().dirname())

require "Shell"

describe Shell::Options do
  before do
    @opt_default = Shell::Options.new(nil)
  end

  it "should default to ignoring  failure" do
    expect(@opt_default.stop_on_failure?()).to eq(false)
  end

  it "should default to echoing commands" do
    expect(@opt_default.echo_command?()).to eq(true)
  end

  it "should default to echoing output" do
    expect(@opt_default.echo_output?()).to eq(true)
  end

  it "should default to combining stdout and stderr" do
    expect(@opt_default.combine_out_err?()).to eq(true)
  end

  it "should default to a live run" do
    expect(@opt_default.dry_run?()).to eq(false)
  end

  it "should support :stop_on_failure" do
    expect(Shell::Options.new([:stop_on_failure]).stop_on_failure?()).to eq(true)
  end

  it "should support :ignore_failure" do
    expect(Shell::Options.new([:ignore_failure]).stop_on_failure?()).to eq(false)
  end

  it "should support :echo_command" do
    expect(Shell::Options.new([:echo_command]).echo_command?()).to eq(true)
  end

  it "should support :silent_command" do
    expect(Shell::Options.new([:silent_command]).echo_command?()).to eq(false)
  end

  it "should support :echo_output" do
    expect(Shell::Options.new([:echo_output]).echo_output?()).to eq(true)
  end

  it "should support :suppress_output" do
    expect(Shell::Options.new([:suppress_output]).echo_output?()).to eq(false)
  end

  it "should support :combine_out_err" do
    expect(Shell::Options.new([:combine_out_err]).combine_out_err?()).to eq(true)
  end

  it "should support :split_out_err" do
    expect(Shell::Options.new([:split_out_err]).combine_out_err?()).to eq(false)
  end

  it "should support :dry_run" do
    expect(Shell::Options.new([:dry_run]).dry_run?()).to eq(true)
  end

  it "should support :live_run" do
    expect(Shell::Options.new([:live_run]).dry_run?()).to eq(false)
  end

end

describe "Shell::execute_shell_commands" do

  it "should be able to perform a single command" do
    out, err, status = Shell::execute_shell_commands("ls #{__FILE__}", [:suppress_output, :silent_command])
    expect(out).to match(/#{__FILE__}/)
  end

  it "should be able to perform a multiple commands, with command and output echo" do
  end

  it "should be able to perform a multiple commands, with command and output echo, stopping on first non-existent command" do
  end

  it "should be able to perform a multiple commands, with command and output echo, stopping on first command reporting a failure" do
  end

  it "should honour dry_run option" do
  end

end

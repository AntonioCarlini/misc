require "pathname.rb"
$LOAD_PATH.unshift(Pathname.new(__FILE__).realpath().dirname())

require "Package"

describe Package::AptOptions do
  before do
    @opt_default = Package::AptOptions.new(nil)
  end

  it "should NOT default to --dry-run" do
    expect(@opt_default.text()).to_not match(/--dry-run/)
  end

  it "should default to --ignore-missing" do
    expect(@opt_default.text()).to match(/--ignore-missing/)
  end

  it "should NOT default to --allow-unauthenticated" do
    expect(@opt_default.text()).to_not match(/--allow-unauthenticated/)
  end

  it "should NOT default to --quite" do
    expect(@opt_default.text()).to_not match(/--quiet/)
  end

  it "should default to --no-install-recommends" do
    expect(@opt_default.text()).to match(/--no-install-recommends/)
  end

  it "should support :dry_run" do
    expect(Package::AptOptions.new([:dry_run]).text()).to match(/--dry-run/)
  end

  it "should support :ignore_missing" do
    expect(Package::AptOptions.new([:ignore_missing]).text()).to match(/--ignore-missing/)
  end

  it "should support :allow_unauthenticated" do
    expect(Package::AptOptions.new([:allow_unauthenticated]).text()).to match(/--allow-unauthenticated/)
  end

  it "should support :quiet" do
    expect(Package::AptOptions.new([:quiet]).text()).to match(/--quiet/)
  end

  it "should support :no_install_recommends" do
    expect(Package::AptOptions.new([:no_install_recommends]).text()).to match(/--no-install-recommends/)
  end

end

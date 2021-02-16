require "pathname.rb"
$LOAD_PATH.unshift(Pathname.new(__FILE__).realpath().dirname())

require "InstallerOptions"

describe "Installer::parse_options" do

  it "should default to --install --configure" do
     ARGV.clear()
     installer_options = Installer::parse_options()
     expect(installer_options.install?()).to eq(true)
     expect(installer_options.configure?()).to eq(true)
     expect(installer_options.dry_run?()).to eq(false)
     expect(installer_options.verbose?()).to eq(false)
  end

  it "should accept --install" do
     ARGV.clear()
     ARGV << "--install"
     installer_options = Installer::parse_options()
     expect(installer_options.install?()).to eq(true)
     expect(installer_options.configure?()).to eq(false)
     expect(installer_options.dry_run?()).to eq(false)
     expect(installer_options.verbose?()).to eq(false)
  end

  it "should accept --configure" do
     ARGV.clear()
     ARGV << "--configure"
     installer_options = Installer::parse_options()
     expect(installer_options.install?()).to eq(false)
     expect(installer_options.configure?()).to eq(true)
     expect(installer_options.dry_run?()).to eq(false)
     expect(installer_options.verbose?()).to eq(false)
  end

  it "should accept --verbose and default to --install and --configure" do
     ARGV.clear()
     ARGV << "--verbose"
     installer_options = Installer::parse_options()
     expect(installer_options.install?()).to eq(true)
     expect(installer_options.configure?()).to eq(true)
     expect(installer_options.dry_run?()).to eq(false)
     expect(installer_options.verbose?()).to eq(true)
  end

  it "should accept --dry-run and default to --install and --configure" do
     ARGV.clear()
     ARGV << "--dry-run"
     installer_options = Installer::parse_options()
     expect(installer_options.install?()).to eq(true)
     expect(installer_options.configure?()).to eq(true)
     expect(installer_options.dry_run?()).to eq(true)
     expect(installer_options.verbose?()).to eq(false)
  end

end

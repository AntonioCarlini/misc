require "./Installer"

describe "Installer::parse_options" do

  it "should default to --install --configure" do
     ARGV.clear()
     options = Installer::parse_options()
     expect(options.install?()).to eq(true)
     expect(options.configure?()).to eq(true)
     expect(options.dry_run?()).to eq(false)
  end

  it "should accept --install" do
     ARGV.clear()
     ARGV << "--install"
     options = Installer::parse_options()
     expect(options.install?()).to eq(true)
     expect(options.configure?()).to eq(false)
     expect(options.dry_run?()).to eq(false)
  end

  it "should accept --configure" do
     ARGV.clear()
     ARGV << "--configure"
     options = Installer::parse_options()
     expect(options.install?()).to eq(false)
     expect(options.configure?()).to eq(true)
     expect(options.dry_run?()).to eq(false)
  end

  it "should accept --dry-run and default to --install and --configure" do
     ARGV.clear()
     ARGV << "--dry-run"
     options = Installer::parse_options()
     expect(options.install?()).to eq(true)
     expect(options.configure?()).to eq(true)
     expect(options.dry_run?()).to eq(true)
  end

end

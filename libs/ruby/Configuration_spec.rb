require "./Configuration"

describe "Configuration::get_value" do

  it "should fetch nis-master" do
     value = Configuration::get_value("nis-master")
     expect(value).to eq("odrc2")
  end

end

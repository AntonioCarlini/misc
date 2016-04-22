require "./UserGroupInfo"

describe "UserGroupInfo::get_value" do

  it "should fetch an existing user: 'builder'" do
     user = UserGroupInfo::get_user("builder")
     expect(user.name()).to eq("builder")
  end

  it "should not fetch a non-existent user: 'no-user-with-this-name'" do
     user = UserGroupInfo::get_user("no-user-with-this-name")
     expect(user).to eq(nil)
  end

  it "should fetch an existing group: 'software'" do
     group = UserGroupInfo::get_group("software")
     expect(group.name()).to eq("software")
  end

  it "should not fetch a non-existent group: 'no-group-with-this-name'" do
     group = UserGroupInfo::get_group("no-group-with-this-name")
     expect(group).to eq(nil)
  end

end

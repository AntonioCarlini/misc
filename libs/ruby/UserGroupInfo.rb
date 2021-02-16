#!/usr/bin/env ruby 

require 'yaml'

module UserGroupInfo
  @@data = nil
  @@users = []
  @@groups = []

  class User
    attr_reader :gid
    attr_reader :group_name
    attr_reader :name
    attr_reader :uid

    def initialize(user_name, uid, group_name, gid)
      @name = user_name
      @uid = uid
      @group_name = group_name
      @gid = gid
    end
  end

  class Group
    attr_reader :gid
    attr_reader :name

    def initialize(group_name, gid)
      @name = group_name
      @gid = gid
    end
  end

  def self.load_data_once(file = nil)
    return unless @@data.nil?()
    if file.nil?()
      file = File.dirname(__FILE__) + "/../../admin/users-and-groups.data"
    end
    @@data = YAML.load_file(file)
    malformed_user = false
    @@data["groups"].each() {
      |node|
      name = node[0]
      data = node[1]
      g = Group.new(name, data["gid"].to_i())
      @@groups << g
    }
    @@data["users"].each() {
      |node|
      name = node[0]
      data = node[1]
      group_name = data["group"]
      g = self.get_group(group_name)
      gid = 65534
      if g.nil?()
        $stderr.puts("Cannot find group #{group_name} for user #{name}")
        malformed_user = true
      else
        gid = g.gid()
      end
      u = User.new(name, data["uid"].to_i(), group_name, gid)
      @@users << u
    }
    raise "At least on badly formed user entry - fix the user/group file" if malformed_user
  end       

  def self.get_group(name)
    self.load_data_once()
    return @@groups.find() { |g| g.name() == name }
  end

  def self.get_user(name)
    self.load_data_once()
    return @@users.find() { |u| u.name() == name }
  end

end # end of UserGroupInfo

# Test cases
if __FILE__ == $0
  ["simh", "builder"].each() {
    |group_name|
    g = UserGroupInfo::get_group(group_name)
    puts("Managed to fetch group #{group_name} and found gid #{g.gid()}")
  }
  ["gituser", "builder"].each() {
    |user_name|
    u = UserGroupInfo::get_user(user_name)
    puts("Managed to fetch user #{user_name} and found uid #{u.uid()} with gid #{u.gid()}")
  }
end

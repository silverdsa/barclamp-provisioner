# Copyright 2011, Dell
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#  http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

package "ipmitool" do
  package_name "OpenIPMI-tools" if node[:platform] =~ /^(redhat|centos)$/
  action :install
end

directory "/root/.ssh" do
  owner "root"
  group "root"
  mode "0700"
  action :create
end

node[:crowbar][:access_keys] = {} if node[:crowbar][:access_keys].nil?

# Build my key
node_modified = false
if ::File.exists?("/root/.ssh/id_rsa.pub") == false
  %x{ssh-keygen -t rsa -f /root/.ssh/id_rsa -N ""}
  str = %x{cat /root/.ssh/id_rsa.pub}.chomp
  node[:crowbar][:root_pub_key] = str
  node[:crowbar][:access_keys][node.name] = str
  node_modified = true
end

# Find provisioner servers and include them.
search(:node, "roles:provisioner-server AND provisioner_config_environment:#{node[:provisioner][:config][:environment]}") do |n|
  if !n[:crowbar][:root_pub_key].nil? or n[:crowbar][:root_pub_key] != node[:crowbar][:access_keys][n.name]
    node[:crowbar][:access_keys][n.name] = n[:crowbar][:root_pub_key] 
    node_modified = true
  end
end
node.save if node_modified

template "/root/.ssh/authorized_keys" do
  owner "root"
  group "root"
  mode "0700"
  action :create
  source "authorized_keys.erb"
  variables(:keys => node[:crowbar][:access_keys])
end

config_file = "/etc/default/chef-client"
config_file = "/etc/sysconfig/chef-client" if node[:platform] =~ /^(redhat|centos)$/

cookbook_file config_file do
  owner "root"
  group "root"
  mode "0644"
  action :create
  source "chef-client"
end


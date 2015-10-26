#
# Cookbook Name:: aerospike-cluster
# Recipe:: package
#
# Copyright 2015, Virender Khatri
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

case node['aerospike']['install_edition']
when 'community'
  if node['aerospike']['package_url'] == 'auto'
    package_url = value_for_platform(
      'ubuntu' => { 'default' => "http://aerospike.com/download/server/#{node['aerospike']['version']}/artifact/ubuntu12" },
      'debian' => { 'default' => "http://aerospike.com/download/server/#{node['aerospike']['version']}/artifact/debian#{node['platform_version']}" },
      %w(amazon centos redhat) => { 'default' => "http://aerospike.com/download/server/#{node['aerospike']['version']}/artifact/el6" }
    )
  else
    package_url = node['aerospike']['package_url']
  end

  package_file = ::File.join(node['aerospike']['parent_dir'], "aerospike-server-community-#{node['aerospike']['version']}-#{node['aerospike']['package_suffix']}.tgz")
when 'enterprise'
  fail 'cookbook does not support aerospike enterprise edition installation'
else
  fail 'cookbook only support aerospike community edition installation'
end

package_checksum = package_sha256sum(node['aerospike']['install_edition'], node['aerospike']['version'], node['aerospike']['package_suffix'])

# download tarball
remote_file package_file do
  source package_url
  checksum package_checksum
  owner node['aerospike']['user']
  group node['aerospike']['group']
  not_if { ::File.exist?(::File.join(node['aerospike']['source_dir'], 'asinstall')) }
end

# extract tarball
execute 'extract_aerospike_package' do
  user node['aerospike']['user']
  group node['aerospike']['group']
  umask node['aerospike']['umask']
  cwd node['aerospike']['parent_dir']
  command "tar xzf #{package_file}"
  creates ::File.join(node['aerospike']['source_dir'], 'asinstall')
end

remote_file package_file do
  action :delete
end

server_package_file = case node['platform']
                      when 'redhat', 'amazon', 'fedora', 'centos'
                        ::File.join(node['aerospike']['source_dir'], "aerospike-server-#{node['aerospike']['install_edition']}-#{node['aerospike']['version']}-1.#{node['aerospike']['package_suffix']}.#{node['kernel']['machine']}.rpm")
                      when 'ubuntu', 'debian'
                        ::File.join(node['aerospike']['source_dir'], "aerospike-server-#{node['aerospike']['install_edition']}-#{node['aerospike']['version']}.#{node['aerospike']['package_suffix']}.#{node['kernel']['machine']}.deb")
                      else
                        fail "unknown platform #{node['platform']}"
                      end

tools_package_file = case node['platform']
                     when 'redhat', 'amazon', 'fedora', 'centos'
                       ::File.join(node['aerospike']['source_dir'], "aerospike-tools-#{node['aerospike']['version']}-1.#{node['aerospike']['package_suffix']}.#{node['kernel']['machine']}.rpm")
                     when 'ubuntu', 'debian'
                       ::File.join(node['aerospike']['source_dir'], "aerospike-tools-#{node['aerospike']['version']}.#{node['aerospike']['package_suffix']}.#{node['kernel']['machine']}.deb")
                     else
                       fail "unknown platform #{node['platform']}"
                     end

package "aerospike-server-#{node['aerospike']['install_edition']}-#{node['aerospike']['version']}-#{node['aerospike']['package_suffix']}" do
  source server_package_file
  provider Chef::Provider::Package::Dpkg if node['platform_family'] == 'debian'
end

package "aerospike-tools-#{node['aerospike']['version']}-#{node['aerospike']['package_suffix']}" do
  source tools_package_file
  provider Chef::Provider::Package::Dpkg if node['platform_family'] == 'debian'
end

directory node['aerospike']['parent_dir'] do
  owner node['aerospike']['user']
  group node['aerospike']['group']
  mode node['aerospike']['mode']
  recursive true
end

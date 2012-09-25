#
# Cookbook Name:: nginx
# Recipe:: default
# Author:: AJ Christensen <aj@junglist.gen.nz>
#
# Copyright 2008-2012, Opscode, Inc.
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
include_recipe 'nginx::ohai_plugin'

case node['nginx']['install_method']
when 'source'
  include_recipe 'nginx::source'
when 'package'
   apt_repository "dotdeb" do
      uri "http://packages.dotdeb.org"
      distribution "stable"
      components ['all']
      key "http://www.dotdeb.org/dotdeb.gpg"
      action :add
    end

  template "/etc/apt/sources.list.d/nginx-stable-lucid.list" do
    source 'nginx.repo.erb'
    owner "root"
    group "root"
    mode "0644"
  end

  execute "prepare repos" do
    command "apt-key adv --keyserver keyserver.ubuntu.com --recv-keys C300EE8C"
    command "apt-get update"
  end

  case node['platform']
  when 'redhat','centos','scientific','amazon','oracle'
    include_recipe 'yum::epel'
  end

#  package 'nginx' do
#    action :remove
#  end

  package 'nginx' do
  #  version node['nginx']['version']
    action :install
  end
#  service 'nginx' do
#    supports :status => true, :restart => true, :reload => true
#    action :enable
#  end
  include_recipe 'nginx::commons'
  include_recipe 'nginx::common_config'
end

execute "make default dirs" do
  command "mkdir -p /var/www/sites"
  :nothing
end

runit_service "nginx"

#service 'nginx' do
#  supports :status => true, :restart => true, :reload => true
#  action :start
#end

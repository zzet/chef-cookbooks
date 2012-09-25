#
# Cookbook Name:: nginx
# Recipe:: source
#
# Author:: Adam Jacob (<adam@opscode.com>)
# Author:: Joshua Timberman (<joshua@opscode.com>)
# Author:: Jamie Winsor (<jamie@vialstudios.com>)
#
# Copyright 2009-2012, Opscode, Inc.
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


nginx_url = node['nginx']['source']['url'] ||
  "http://nginx.org/download/nginx-#{node['nginx']['version']}.tar.gz"

unless(node['nginx']['source']['prefix'])
  node.set['nginx']['source']['prefix'] = "/opt/nginx-#{node['nginx']['version']}"
end
unless(node['nginx']['source']['conf_path'])
  node.set['nginx']['source']['conf_path'] = "#{node['nginx']['dir']}/nginx.conf"
end
unless(node['nginx']['source']['default_configure_flags'])
  node.set['nginx']['source']['default_configure_flags'] = [
    "--prefix=#{node['nginx']['source']['prefix']}",
    "--conf-path=#{node['nginx']['dir']}/nginx.conf"
  ]
end
node.set['nginx']['binary']          = "#{node['nginx']['source']['prefix']}/sbin/nginx"
node.set['nginx']['daemon_disable']  = true

include_recipe "nginx::ohai_plugin"
include_recipe "build-essential"

cache_path = Chef::Config['file_cache_path'] || '/tmp'
src_filepath  = "#{cache_path}/nginx-#{node['nginx']['version']}.tar.gz"
packages = value_for_platform(
    ["centos","redhat","fedora"] => {'default' => ['pcre-devel', 'openssl-devel']},
    "default" => ['libpcre3', 'libpcre3-dev', 'libssl-dev']
  )

packages.each do |devpkg|
  package devpkg
end

remote_file nginx_url do
  source nginx_url
  checksum node['nginx']['source']['checksum']
  path src_filepath
  backup false
end

user node['nginx']['user'] do
  system true
  shell "/bin/false"
  home "/var/www"
end

include_recipe 'nginx::commons'

node.run_state['nginx_force_recompile'] = false
node.run_state['nginx_configure_flags'] = 
  node['nginx']['source']['default_configure_flags'] | node['nginx']['configure_flags']

node['nginx']['source']['modules'].each do |ngx_module|
  if ngx_module.include?("::")
    include_recipe ngx_module
  else
    include_recipe "nginx::#{ngx_module}"
  end
end

directory "#{cache_path}/nginx-patches"

patch_paths = []

node['nginx']['source']['patches'].each do |patch|
  patch_basename = patch['basename'] || File.basename(URI(patch['source']).path)
  patch_path = "#{cache_path}/nginx-patches/#{patch_basename}"
  patch_paths << patch_path unless patch['action'] == "delete"

  remote_file patch['source'] do
    path patch_path
    source patch['source']
    checksum patch['checksum']
    action patch['action'] if patch['action']
    notifies :create, "ruby_block[patch change forces nginx recompile]", :immediately
  end

  ruby_block "patch change forces nginx recompile" do
    block { node.run_state['nginx_force_recompile'] = true }
    action :nothing
  end
end

configure_flags = node.run_state['nginx_configure_flags']

apply_patches = patch_paths.map { |patch_path| "patch -p0 < #{patch_path}" }.join(" && ").concat(" &&") if patch_paths.any?

bash "compile_nginx_source" do
  cwd ::File.dirname(src_filepath)
  code <<-EOH
    tar zxf #{::File.basename(src_filepath)} -C #{::File.dirname(src_filepath)} &&
    cd nginx-#{node['nginx']['version']} &&
    #{apply_patches}
    ./configure #{node.run_state['nginx_configure_flags'].join(" ")} &&
    make &&
    make install &&
    rm -f #{node['nginx']['dir']}/nginx.conf
  EOH
  
  not_if do
    node.run_state['nginx_force_recompile'] == false &&
      node.automatic_attrs['nginx'] &&
      node.automatic_attrs['nginx']['version'] == node['nginx']['version'] &&
      node.automatic_attrs['nginx']['configure_arguments'].sort == configure_flags.sort
  end
end

node.run_state.delete(:nginx_configure_flags)
node.run_state.delete(:nginx_force_recompile)

case node['nginx']['init_style']
when "runit"
  node.set['nginx']['src_binary'] = node['nginx']['binary']
  include_recipe "runit"

  runit_service "nginx"

  service "nginx" do
    supports :status => true, :restart => true, :reload => true
    reload_command "[[ -f #{node['nginx']['pid']} ]] && kill -HUP `cat #{node['nginx']['pid']}` || true"
  end
when "bluepill"
  include_recipe "bluepill"

  template "#{node['bluepill']['conf_dir']}/nginx.pill" do
    source "nginx.pill.erb"
    mode 0644
    variables(
      :working_dir => node['nginx']['source']['prefix'],
      :src_binary => node['nginx']['binary'],
      :nginx_dir => node['nginx']['dir'],
      :log_dir => node['nginx']['log_dir'],
      :pid => node['nginx']['pid']
    )
  end

  bluepill_service "nginx" do
    action [ :enable, :load ]
  end

  service "nginx" do
    supports :status => true, :restart => true, :reload => true
    reload_command "[[ -f #{node['nginx']['pid']} ]] && kill -HUP `cat #{node['nginx']['pid']}` || true"
    action :nothing
  end
else
  node.set['nginx']['daemon_disable'] = false

  template "/etc/init.d/nginx" do
    source "nginx.init.erb"
    owner "root"
    group "root"
    mode "0755"
    variables(
      :working_dir => node['nginx']['source']['prefix'],
      :src_binary => node['nginx']['binary'],
      :nginx_dir => node['nginx']['dir'],
      :log_dir => node['nginx']['log_dir'],
      :pid => node['nginx']['pid']
    )
  end

  defaults_path = case node['platform']
    when 'debian', 'ubuntu'
      '/etc/default/nginx'
    else
      '/etc/sysconfig/nginx'
  end
  template defaults_path do
    source "nginx.sysconfig.erb"
    owner "root"
    group "root"
    mode "0644"
  end

  service "nginx" do
    supports :status => true, :restart => true, :reload => true
    action :enable
  end
end

include_recipe 'nginx::common_config'

cookbook_file "#{node['nginx']['dir']}/mime.types" do
  source "mime.types"
  owner "root"
  group "root"
  mode "0644"
  notifies :reload, 'service[nginx]', :immediately
end

service "nginx" do
  action :start
end

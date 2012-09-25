#
# Cookbook Name:: fightnews
# Recipe:: default
#
# Copyright 2012, YOUR_COMPANY_NAME
#
# All rights reserved - Do Not Redistribute
#
include_recipe "mysql::server"
include_recipe "php"
include_recipe "php::module_apc"
include_recipe "php::module_curl"
include_recipe "php::module_gd"
include_recipe "php::module_mysql"
include_recipe "php::module_memcache"
include_recipe "memcached"
include_recipe "imagemagick"
# include_recipe "host"

# Some neat package (subversion is needed for "subversion" chef ressource)
%w{ php5-fpm }.each do |a_package|
  package a_package
end

php_pear "pdo" do
  action :install
end

# Requried to install APC.
package "libpcre3-dev"

# Install APC.
php_pear "apc" do
  directives(:shm_size => 128)
  version "3.1.6" #ARGH!!! debuging enabled on APC builds circa 5/2011. Pin back.
  action :install
end

# Configure the development site
template "blacklist.conf" do
  path "#{node['nginx']['dir']}/preconf/blacklist.conf"
  source "blacklist.conf.erb"
  owner "root"
  group "root"
  mode "0644"
  notifies :reload, 'service[nginx]', :immediately
end

template "drupal7.conf" do
  path "#{node['nginx']['dir']}/preconf/drupal7.conf"
  source "drupal7.conf.erb"
  owner "root"
  group "root"
  mode "0644"
  notifies :reload, 'service[nginx]', :immediately
end

template "drupal_boost.conf" do
  path "#{node['nginx']['dir']}/preconf/drupal_boost.conf"
  source "drupal_boost.conf.erb"
  owner "root"
  group "root"
  mode "0644"
  notifies :reload, 'service[nginx]', :immediately
end


template "drupal_fight.conf" do
  path "#{node['nginx']['dir']}/preconf/drupal_fight.conf"
  source "drupal_fight.conf.erb"
  owner "root"
  group "root"
  mode "0644"
  notifies :reload, 'service[nginx]', :immediately
end

template "#{node['nginx']['dir']}/sites-available/fightnews.ru.conf" do
  source "fightnews.ru.conf.erb"
  variables :server_name => "fightnews.ru", :server_aliases => ["www.fightnews.ru"], :docroot => "#{node['nginx']['site_dir']}/fightnews.ru"
  owner "root"
  group "root"
  mode 0644
end

nginx_site 'fightnews.ru.conf' do
  enable node['nginx']['fightnews.ru_site_enabled']
end

# Add apc conf until we can correctly config apc
#bash "apc_shm_size_conf" do
#  code "echo apc.shm_size = 70 >> /etc/php5/apache2/conf.d/apc.ini"
#  only_if { "grep shm_size /etc/php5/apache2/conf.d/apc.ini" }
#end

node.set_unless['fightnews']['site']['db']['password'] = secure_password 
node.set_unless['fightnews']['total']['db']['password'] = secure_password 

# Add an admin user to mysql

execute "add-site-db" do
  command "#{node['mysql']['mysql_bin']} -u root -p#{node[:mysql][:server_root_password]} -e \"" +
      "CREATE DATABASE IF NOT EXISTS #{node['fightnews']['site']['db']['name']} CHARACTER SET 'utf8' COLLATE 'utf8_general_ci';\" " +
      "mysql"
  action :run
  ignore_failure true
end

execute "add-site-db-user" do
  command "#{node['mysql']['mysql_bin']} -u root -p#{node[:mysql][:server_root_password]} -e \"" +
      "CREATE USER '#{node['fightnews']['site']['db']['user']}'@'localhost' IDENTIFIED BY '#{node['fightnews']['site']['db']['password']}';" +
      "GRANT ALL PRIVILEGES ON #{node['fightnews']['site']['db']['name']}.* TO '#{node['fightnews']['site']['db']['user']}'@'localhost' WITH GRANT OPTION;\" " +
      "mysql"
  action :run
  only_if { `#{node['mysql']['mysql_bin']} -u root -p#{node[:mysql][:server_root_password]} -D mysql -r -B -N -e \"SELECT COUNT(*) FROM user where User='#{node['fightnews']['site']['db']['user']}' and Host = 'localhost'"`.to_i == 0 }
  ignore_failure true
end


execute "add-total-db" do
  command "#{node['mysql']['mysql_bin']} -u root -p#{node[:mysql][:server_root_password]} -e \"" +
      "CREATE DATABASE IF NOT EXISTS #{node['fightnews']['total']['db']['name']} CHARACTER SET 'utf8' COLLATE 'utf8_general_ci';\" "+
      "mysql"
  action :run
  ignore_failure true
end

execute "add-total-db-user" do
  command "#{node['mysql']['mysql_bin']} -u root -p#{node[:mysql][:server_root_password]} -e \"" +
      "CREATE USER '#{node['fightnews']['total']['db']['user']}'@'localhost' IDENTIFIED BY '#{node['fightnews']['total']['db']['password']}';" +
      "GRANT ALL PRIVILEGES ON #{node['fightnews']['total']['db']['name']}.* TO '#{node['fightnews']['total']['db']['user']}'@'localhost' WITH GRANT OPTION;\" " +
      "mysql"
  action :run
  only_if { `#{node['mysql']['mysql_bin']} -u root -p#{node[:mysql][:server_root_password]} -D mysql -r -B -N -e \"SELECT COUNT(*) FROM user where User='#{node['fightnews']['total']['db']['user']}' and Host = 'localhost'"`.to_i == 0 }
  ignore_failure true
end


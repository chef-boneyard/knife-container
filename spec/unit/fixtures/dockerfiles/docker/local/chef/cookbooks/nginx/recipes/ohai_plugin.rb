#
# Cookbook Name:: nginx
# Recipe:: ohai_plugin
#
# Author:: Jamie Winsor (<jamie@vialstudios.com>)
#
# Copyright 2012-2013, Riot Games
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

ohai 'reload_nginx' do
  plugin 'nginx'
  action :nothing
end

template "#{node['ohai']['plugin_path']}/nginx.rb" do
  source 'plugins/nginx.rb.erb'
  owner  'root'
  group  node['root_group']
  mode   '0755'
  notifies :reload, 'ohai[reload_nginx]', :immediately
end

include_recipe 'ohai::default'

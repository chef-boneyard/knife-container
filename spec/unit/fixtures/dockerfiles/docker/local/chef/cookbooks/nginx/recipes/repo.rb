#
# Cookbook Name:: nginx
# Recipe:: repo
# Author:: Nick Rycar <nrycar@bluebox.net>
#
# Copyright 2008-2013, Opscode, Inc.
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

case node['platform_family']
when 'rhel', 'fedora'

  yum_repository 'nginx' do
    description 'Nginx.org Repository'
    baseurl         node['nginx']['upstream_repository']
    gpgkey      'http://nginx.org/keys/nginx_signing.key'
    action :create
  end

when 'debian'
  include_recipe 'apt::default'

  apt_repository 'nginx' do
    uri          node['nginx']['upstream_repository']
    distribution node['lsb']['codename']
    components   %w(nginx)
    deb_src      true
    key          'http://nginx.org/keys/nginx_signing.key'
  end
end

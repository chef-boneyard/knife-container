#
# Cookbook Name:: rsyslog
# Attributes:: default
#
# Copyright 2009-2013, Opscode, Inc.
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

default['rsyslog']['log_dir']                   = '/srv/rsyslog'
default['rsyslog']['server']                    = false
default['rsyslog']['use_relp']                  = false
default['rsyslog']['relp_port']                 = 20_514
default['rsyslog']['protocol']                  = 'tcp'
default['rsyslog']['port']                      = 514
default['rsyslog']['server_ip']                 = nil
default['rsyslog']['server_search']             = 'role:loghost'
default['rsyslog']['remote_logs']               = true
default['rsyslog']['per_host_dir']              = '%$YEAR%/%$MONTH%/%$DAY%/%HOSTNAME%'
default['rsyslog']['max_message_size']          = '2k'
default['rsyslog']['preserve_fqdn']             = 'off'
default['rsyslog']['high_precision_timestamps'] = false
default['rsyslog']['repeated_msg_reduction']    = 'on'
default['rsyslog']['logs_to_forward']           = '*.*'
default['rsyslog']['enable_imklog']             = true
default['rsyslog']['config_prefix']             = '/etc'
default['rsyslog']['default_file_template']    = nil
default['rsyslog']['default_remote_template']   = nil
default['rsyslog']['rate_limit_interval']       = nil
default['rsyslog']['rate_limit_burst']          = nil
default['rsyslog']['enable_tls']                = false
default['rsyslog']['tls_ca_file']               = nil
default['rsyslog']['tls_certificate_file']      = nil
default['rsyslog']['tls_key_file']              = nil
default['rsyslog']['tls_auth_mode']             = 'anon'
default['rsyslog']['use_local_ipv4']            = false

# The most likely platform-specific attributes
default['rsyslog']['service_name']              = 'rsyslog'
default['rsyslog']['user']                      = 'root'
default['rsyslog']['group']                     = 'adm'
default['rsyslog']['priv_seperation']           = false
default['rsyslog']['modules']                   = %w(imuxsock imklog)

case node['platform']
when 'ubuntu'
  # syslog user introduced with natty package
  if node['platform_version'].to_f < 10.10
    default['rsyslog']['user'] = 'syslog'
    default['rsyslog']['group'] = 'adm'
    default['rsyslog']['priv_seperation'] = true
  end
when 'arch'
  default['rsyslog']['service_name'] = 'rsyslogd'
when 'smartos'
  default['rsyslog']['config_prefix'] = '/opt/local/etc'
  default['rsyslog']['modules'] = %w(immark imsolaris imtcp imudp)
  default['rsyslog']['group'] = 'root'
when 'omnios'
  default['rsyslog']['service_name'] = 'system/rsyslogd'
  default['rsyslog']['modules'] = %w(immark imsolaris imtcp imudp)
  default['rsyslog']['group'] = 'root'
end

# 50-default template attributes

default['rsyslog']['default_log_dir'] = '/var/log'
case node['platform_family']
when 'rhel'
  # format { facility => destination }
  default['rsyslog']['default_facility_logs'] = {
    '*.info;mail.none;authpriv.none;cron.none' => "#{node['rsyslog']['default_log_dir']}/messages",
    'authpriv.*' => "#{node['rsyslog']['default_log_dir']}/secure",
    'mail.*' => "-#{node['rsyslog']['default_log_dir']}/maillog",
    'cron.*' => "#{node['rsyslog']['default_log_dir']}/cron",
    '*.emerg' => '*',
    'uucp,news.crit' => "#{node['rsyslog']['default_log_dir']}/spooler",
    'local7.*' => "#{node['rsyslog']['default_log_dir']}/boot.log"
  }
else
  # format { facility => destination }
  default['rsyslog']['default_facility_logs'] = {
    'auth,authpriv.*' => "#{node['rsyslog']['default_log_dir']}/auth.log",
    '*.*;auth,authpriv.none' => "-#{node['rsyslog']['default_log_dir']}/syslog",
    'daemon.*' => "-#{node['rsyslog']['default_log_dir']}/daemon.log",
    'kern.*' => "-#{node['rsyslog']['default_log_dir']}/kern.log",
    'mail.*' => "-#{node['rsyslog']['default_log_dir']}/mail.log",
    'user.*' => "-#{node['rsyslog']['default_log_dir']}/user.log",
    'mail.info' => "-#{node['rsyslog']['default_log_dir']}/mail.info",
    'mail.warn' => "-#{node['rsyslog']['default_log_dir']}/mail.warn",
    'mail.err' => "#{node['rsyslog']['default_log_dir']}/mail.err",
    'news.crit' => "#{node['rsyslog']['default_log_dir']}/news/news.crit",
    'news.err' => "#{node['rsyslog']['default_log_dir']}/news/news.err",
    'news.notice' => "-#{node['rsyslog']['default_log_dir']}/news/news.notice",
    '*.=debug;auth,authpriv.none;news.none;mail.none' => "-#{node['rsyslog']['default_log_dir']}/debug",
    '*.=info;*.=notice;*.=warn;auth,authpriv.none;cron,daemon.none;mail,news.none' => "-#{node['rsyslog']['default_log_dir']}/messages",
    '*.emerg' => '*',
    'daemon.*;mail.*;news.err;*.=debug;*.=info;*.=notice;*.=warn' => '|/dev/xconsole'
  }
end

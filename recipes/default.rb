#
# Cookbook Name:: sendmail-ses
# Recipe:: default
#
# Copyright 2015, TableXI
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

if node.attribute? 'sendmail_ses'
  log 'check username, password, and domain' do
    level :fatal
    message 'Username, password and domain must be defined'
    not_if { node['sendmail_ses']['username'] }
    not_if { node['sendmail_ses']['password'] }
    not_if { node['sendmail_ses']['domain'] }
  end

	if node['sendmail_ses']['secure_tunnel'] 
		package 'stunnel'
		frequency = 86400 * node['sendmail_ses']['cert_frequency']
		smtp_host = 'localhost'
		smtp_port = node['sendmail_ses']['secure_port'] || 2525

		unless File.exist?("#{ node['sendmail_ses']['cert_file'] }") && File.mtime("#{ node['sendmail_ses']['cert_file'] }") > Time.now - frequency 

 			subject = "/C=#{ node['sendmail_ses']['subject_c'] }/ST=#{ node['sendmail_ses']['subject_st'] }/L=#{ node['sendmail_ses']['subject_l'] }/O=#{ node['sendmail_ses']['subject_o'] }/OU=#{ node['sendmail_ses']['subject_ou'] }/CN=#{ node['sendmail_ses']['subject_cn'] }" 

			execute 'create cert' do
			    command "openssl req -new -out  -keyout #{ node['sendmail_ses']['cert_file'] } -nodes -x509 -days #{ node['sendmail_ses']['cert_frequency'] } -subj \"#{ subject }\""
				action :run, :immediately
				notifies :restart, 'service[start stunnel]', :immediately
			end	
		end
		
		template "/etc/init.d/stunnel" do
			source 'stunnel.erb'
			mode '0755'
			notifies :restart, 'service[start stunnel]', :immediately
		end	
	
		template "/etc/stunnel/stunnel.conf" do
			source 'stunnel.conf.erb'
			variables(
				port: node['sendmail_ses']['port'] || '465',
				secure_port: smtp_port,
				aws_region: node['sendmail_ses']['aws_region']
			)
			notifies :restart, 'service[start stunnel]', :immediately
		end	
	
		service 'start stunnel' do
		    service_name 'stunnel'
		    supports :status => true, :start => true, :stop => true, :restart => true
		    action [ :enable, :start ]
  		end

	else
		smtp_host = "email-smtp.#{ node['sendmail_ses']['aws_region'] }.amazonaws.com"
		smtp_port = node['sendmail_ses']['port'] || 25
	end

  %w(m4 sendmail-cf).each do |p|
    package p
  end

  execute 'add_ses_authinfo' do
    command 'makemap hash /etc/mail/authinfo.db < /etc/mail/authinfo.ses'
    action :nothing
  end

  template '/etc/mail/authinfo.ses' do
    source 'authinfo.ses.erb'
    variables(
      username: node['sendmail_ses']['username'],
      password: node['sendmail_ses']['password'],
      host: smtp_host
    )
    notifies :run, 'execute[add_ses_authinfo]', :immediately
  end

  execute 'add_ses_access' do
    command 'makemap hash /etc/mail/access.db < /etc/mail/access.ses'
    action :nothing
  end

  template '/etc/mail/access.ses' do
    source 'access.ses.erb'
    variables(
      host: smtp_host
    )
    notifies :run, 'execute[add_ses_access]', :immediately
  end

  ses_cf_path = node['sendmail']['ses_cf_path']

  directory ses_cf_path do
    recursive true
  end

  ruby_block 'add_include_to_sendmail_mc' do
    action :nothing
    block do
      rc = Chef::Util::FileEdit.new('/etc/mail/sendmail.mc')
      rc.insert_line_after_match(/cf.m4/, <<-CMD
dnl #
dnl # Amazon SES integration
dnl #
include(`#{ses_cf_path}/ses.cf')dnl
CMD
                                )
      rc.write_file
    end
    notifies :run, 'execute[sendmail_writeable]', :immediately
    notifies :run, 'execute[regenerate_sendmail_cf]', :immediately
    notifies :run, 'execute[sendmail_read_only]', :immediately
  end

  template "#{ses_cf_path}/ses.cf" do
    source 'ses.cf.erb'
    variables(
      port: smtp_port,
      domain: node['sendmail_ses']['domain'],
      host: smtp_host
    )
    notifies :run, 'ruby_block[add_include_to_sendmail_mc]', :immediately
  end

  execute 'sendmail_writeable' do
    command 'chmod 666 /etc/mail/sendmail.cf'
    action :nothing
  end

  execute 'regenerate_sendmail_cf' do
    command 'm4 /etc/mail/sendmail.mc > /etc/mail/sendmail.cf'
    action :nothing
  end

  execute 'sendmail_read_only' do
    command 'chmod 644 /etc/mail/sendmail.cf'
    action :nothing
    notifies :restart, 'service[ses_sendmail]', :immediately
  end

  service 'ses_sendmail' do
    service_name 'sendmail'
    notifies :run, 'execute[sendmail_test]', :immediately
  end

  execute 'sendmail_test' do
    command "echo \
'Subject:#{node.name}_sendmail_test\nThis is a test email using ses.\n' \
| /usr/sbin/sendmail \
-f #{node['sendmail_ses']['test_user']}@#{node['sendmail_ses']['domain']} \
#{node['sendmail_ses']['test_email']}"
    action :nothing
    only_if { node['sendmail_ses']['test_user'] }
    only_if { node['sendmail_ses']['test_email'] }
  end
end

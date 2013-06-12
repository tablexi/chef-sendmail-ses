#
# Cookbook Name:: sendmail-ses
# Recipe:: default
#
# Copyright (C) 2013 TABLE XI
# 
# All rights reserved - Do Not Redistribute
#

if node.attribute? 'sendmail_ses'
  unless node[:sendmail_ses][:username] && node[:sendmail_ses][:password] && node[:sendmail_ses][:domain]
    log 'check username, password, and domain' do
      level :fatal
      message 'Username, password and domain must be defined in the sendmail_ses attribute hash'
    end
  end

  %w(m4 sendmail-cf).each do |p|
    package p
  end

  template '/etc/mail/authinfo.ses' do
    source 'authinfo.ses.erb'
    variables(
      :username => node[:sendmail_ses][:username],
      :password => node[:sendmail_ses][:password]
    )
    notifies :run, "execute[add_ses_authinfo]", :immediately
  end

  execute 'add_ses_authinfo' do
    command 'makemap hash /etc/mail/authinfo.db < /etc/mail/authinfo.ses'
    action :nothing
  end

  file '/etc/mail/access.ses' do
    content <<-CMD
Connect:email-smtp.us-east-1.amazonaws.com RELAY
Connect:ses-smtp-prod-335357831.us-east-1.elb.amazonaws.com RELAY
CMD
    notifies :run, "execute[add_ses_access]", :immediately
  end

  execute 'add_ses_access' do
    command 'makemap hash /etc/mail/access.db < /etc/mail/access.ses'
    action :nothing
  end

  ruby_block 'add_include_to_sendmail_mc' do
    block do
      rc = Chef::Util::FileEdit.new('/etc/mail/sendmail.mc')
      rc.insert_line_after_match(/include(`\/usr\/share\/sendmail-cf\/m4\/cf.m4')dnl/, <<-CMD
dnl #
dnl # Amazon SES integration
dnl #
include(`/usr/share/sendmail-cf/ses/ses.cf')dnl
CMD
      )
      rc.write_file
    end
    not_if { File.exist?('/usr/share/sendmail-cf/ses/ses.cf') }
    action :nothing
  end

  directory '/usr/share/sendmail-cf/ses'

  template '/usr/share/sendmail-cf/ses/ses.cf' do
    source 'ses.cf.erb'
    variables(
      :port => node[:sendmail_ses][:port] || '25',
      :domain => node[:sendmail_ses][:domain]
    )
    notifies :run, "execute[sendmail_writeable]", :immediately
    notifies :run, "execute[regenerate_sendmail_cf]", :immediately
    notifies :run, "execute[sendmail_read_only]", :immediately
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
    notifies :restart, "service[ses_sendmail]", :immediately
  end

  service 'ses_sendmail' do
    service_name 'sendmail'
    notifies :run, "execute[sendmail_test]", :immediately
  end

  execute 'sendmail_test' do
    command "echo 'Subject:test.com_sendmail_test\nThis is a test email using ses.\n' | /usr/sbin/sendmail -f test@#{node[:sendmail_ses][:domain]} #{node[:sendmail_ses][:test_email]}"
    action :nothing
    only_if { node[:sendmail_ses][:test_email] }
  end
end
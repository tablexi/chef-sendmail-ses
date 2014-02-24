require 'chefspec'
require 'chefspec/berkshelf'

describe 'sendmail-ses::default' do
  before  do
    @chef_run = ChefSpec::Runner.new(:log_level => :fatal, :platform => 'amazon', :version => '2012.09')
  end

  it 'exit if username, password and domain are not set' do
    stub_command('grep ses.cf /etc/mail/sendmail.mc').and_return(true)
    @chef_run.node.set[:sendmail_ses] = {}
    @chef_run.converge 'sendmail-ses::default'
    expect(@chef_run).to write_log('Username, password and domain must be defined in the sendmail_ses attribute hash')
    expect(@chef_run).not_to restart_service('sendmail')
  end

  context 'basic setup' do
    before do
      @chef_run.node.set[:sendmail_ses] = {
        'username' => 'test',
        'password' => 'test',
        'domain' => 'test.com'
      }
      stub_command('grep ses.cf /etc/mail/sendmail.mc').and_return(false)
      @chef_run.converge 'sendmail-ses::default'
    end

    it 'include m4 and sendmail-cf package' do
      expect(@chef_run).to install_package('m4')
      expect(@chef_run).to install_package('sendmail-cf')
    end

    it 'create authinfo.ses with content' do
      expect(@chef_run).to create_template('/etc/mail/authinfo.ses')
      expect(@chef_run).to render_file('/etc/mail/authinfo.ses').with_content('"U:root" "I:test" "P:test" "M:LOGIN"')
    end

    it 'template authinfo.ses should notify add_ses_authinfo' do
      template = @chef_run.template('/etc/mail/authinfo.ses')
      expect(template).to notify('execute[add_ses_authinfo]')
    end

    it 'create access.ses with content' do
      expect(@chef_run).to create_file('/etc/mail/access.ses')
      expect(@chef_run).to render_file('/etc/mail/access.ses').with_content(<<-CMD
Connect:email-smtp.us-east-1.amazonaws.com RELAY
Connect:ses-smtp-prod-335357831.us-east-1.elb.amazonaws.com RELAY
CMD
)
    end

    it 'template access.ses should notify add_ses_access' do
      f = @chef_run.file('/etc/mail/access.ses')
      expect(f).to notify('execute[add_ses_access]')
    end

    it 'should create ses directory' do
      expect(@chef_run).to create_directory('/usr/share/sendmail-cf/ses')
    end

    it 'should add code to ses.cf with domain' do
      expect(@chef_run).to create_template('/usr/share/sendmail-cf/ses/ses.cf')
      expect(@chef_run).to render_file('/usr/share/sendmail-cf/ses/ses.cf').with_content('test.com')
    end

    it 'should run add_include_to_sendmail_mc' do
      expect(@chef_run).to run_ruby_block('add_include_to_sendmail_mc')
    end

    it 'add_include_to_sendmail_mc should notify sendmail_writeable' do
      r = @chef_run.ruby_block('add_include_to_sendmail_mc')
      expect(r).to notify('execute[sendmail_writeable]').to(:run)
    end

    it 'add_include_to_sendmail_mc should notify regenerate_sendmail_cf' do
      r = @chef_run.ruby_block('add_include_to_sendmail_mc')
      expect(r).to notify('execute[regenerate_sendmail_cf]').to(:run)
    end

    it 'add_include_to_sendmail_mc should notify sendmail_read_only' do
      r = @chef_run.ruby_block('add_include_to_sendmail_mc')
      expect(r).to notify('execute[sendmail_read_only]').to(:run)
    end

    it 'sendmail_read_only should notify service ses_sendmail' do
      e = @chef_run.execute('sendmail_read_only')
      expect(e).to notify('service[ses_sendmail]').to(:restart)
    end

    it 'ses_sendmail should notify execute sendmail_test' do
      s = @chef_run.service('ses_sendmail')
      expect(s).to notify('execute[sendmail_test]').to(:run)
    end
  end

  context 'port' do
    before do
      @chef_run.node.set[:sendmail_ses] = {
        'username' => 'test1',
        'password' => 'test',
        'domain' => 'test.com'
      }
      stub_command('grep ses.cf /etc/mail/sendmail.mc').and_return(false)
    end

    it 'should use the default port' do
      @chef_run.converge 'sendmail-ses::default'
      expect(@chef_run).to create_template('/usr/share/sendmail-cf/ses/ses.cf')
      expect(@chef_run).to render_file('/usr/share/sendmail-cf/ses/ses.cf').with_content("define(`RELAY_MAILER_ARGS', `TCP $h 25')dnl")
    end

    it 'should use the configured port' do
      @chef_run.node.set[:sendmail_ses][:port] = '587'
      @chef_run.converge 'sendmail-ses::default'
      expect(@chef_run).to create_template('/usr/share/sendmail-cf/ses/ses.cf')
      expect(@chef_run).to render_file('/usr/share/sendmail-cf/ses/ses.cf').with_content("define(`RELAY_MAILER_ARGS', `TCP $h 587')dnl")
    end
  end

  context 'test email' do
    before do
      @chef_run.node.set[:sendmail_ses] = {
        'username' => 'test1',
        'password' => 'test',
        'domain' => 'test.com'
      }
      stub_command('grep ses.cf /etc/mail/sendmail.mc').and_return(false)
    end

    it 'should not send a test email' do
      @chef_run.converge 'sendmail-ses::default'
      expect(@chef_run).not_to run_execute("sendmail_test")
    end
  end
end

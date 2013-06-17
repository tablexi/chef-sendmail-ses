require 'chefspec'

describe 'sendmail-ses::default' do
  before  do
    Chef::Recipe.any_instance.stub(:include_recipe)
    @chef_run = ChefSpec::ChefRunner.new(:log_level => :fatal, :platform => 'amazon', :version => '2012.09')
  end

  it 'exit if username, password and domain are not set' do
    @chef_run.node.set[:sendmail_ses] = {}
    @chef_run.converge 'sendmail-ses::default'
    expect(@chef_run).to log('Username, password and domain must be defined in the sendmail_ses attribute hash')
    expect(@chef_run).not_to restart_service('sendmail')
  end

  describe 'basic setup' do
    before do
      @chef_run.node.set[:sendmail_ses] = {
        'username' => 'test',
        'password' => 'test',
        'domain' => 'test.com'
      }
      @chef_run.converge 'sendmail-ses::default'
    end

    it 'include m4 and sendmail-cf package' do
      expect(@chef_run).to install_package('m4')
      expect(@chef_run).to install_package('sendmail-cf')
    end

    it 'create authinfo.ses with content' do
      expect(@chef_run).to create_file '/etc/mail/authinfo.ses'
      expect(@chef_run).to create_file_with_content '/etc/mail/authinfo.ses', '"U:root" "I:test" "P:test" "M:LOGIN"'
    end

    it 'should add authinfo.ses to authinfo.db' do
      expect(@chef_run).to execute_command('makemap hash /etc/mail/authinfo.db < /etc/mail/authinfo.ses')
    end

    it 'create access.ses with content' do
      expect(@chef_run).to create_file '/etc/mail/access.ses'
      expect(@chef_run).to create_file_with_content '/etc/mail/access.ses', <<-CMD
Connect:email-smtp.us-east-1.amazonaws.com RELAY
Connect:ses-smtp-prod-335357831.us-east-1.elb.amazonaws.com RELAY
CMD
    end

    it 'should add access.ses to access.db' do
      expect(@chef_run).to execute_command('makemap hash /etc/mail/access.db < /etc/mail/access.ses')
    end

    it 'should create ses directory' do
      expect(@chef_run).to create_directory('/usr/share/sendmail-cf/ses')
    end

    it 'should add code to ses.cf with domain' do
      expect(@chef_run).to create_file '/usr/share/sendmail-cf/ses/ses.cf'
      expect(@chef_run).to create_file_with_content('/usr/share/sendmail-cf/ses/ses.cf', 'test.com')
    end

    it 'should make the sendmail.mc writeable' do
      expect(@chef_run).to execute_command('chmod 666 /etc/mail/sendmail.cf')
    end

    it 'should regenerate sendmail.cf' do
      expect(@chef_run).to execute_command('m4 /etc/mail/sendmail.mc > /etc/mail/sendmail.cf')
    end

    it 'should reset permissions of sendmail.mc to read only' do
      expect(@chef_run).to execute_command('chmod 644 /etc/mail/sendmail.cf')
    end

    it 'should notify sendmail to restart' do
      @chef_run.execute('sendmail_read_only').should notify('service[ses_sendmail]', :restart)
    end
  end

  describe 'port' do
    before do
      @chef_run.node.set[:sendmail_ses] = {
        'username' => 'test1',
        'password' => 'test',
        'domain' => 'test.com'
      }
    end

    it 'should use the default port' do
      @chef_run.converge 'sendmail-ses::default'
      expect(@chef_run).to create_file_with_content('/usr/share/sendmail-cf/ses/ses.cf', "define(`RELAY_MAILER_ARGS', `TCP $h 25')dnl")
    end

    it 'should use the configured port' do
      @chef_run.node.set[:sendmail_ses][:port] = '587'
      @chef_run.converge 'sendmail-ses::default'
      expect(@chef_run).to create_file_with_content('/usr/share/sendmail-cf/ses/ses.cf', "define(`RELAY_MAILER_ARGS', `TCP $h 587')dnl")
    end
  end

  describe 'test email' do
    before do
      @chef_run.node.set[:sendmail_ses] = {
        'username' => 'test1',
        'password' => 'test',
        'domain' => 'test.com'
      }
    end

    it 'should not send a test email' do
      @chef_run.converge 'sendmail-ses::default'
      expect(@chef_run).not_to execute_command("echo 'Subject:test.com_sendmail_test\nThis is a test email using ses.\n' | /usr/sbin/sendmail -f test@test.com test2@test2.com")
    end

    it 'should send test email on first run' do
      @chef_run.node.set[:sendmail_ses][:test_email] = 'test2@test2.com'
      @chef_run.converge 'sendmail-ses::default'
      expect(@chef_run).to execute_command("echo 'Subject:test.com_sendmail_test\nThis is a test email using ses.\n' | /usr/sbin/sendmail -f test@test.com test2@test2.com")
    end
  end
end

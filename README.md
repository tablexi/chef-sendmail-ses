# sendmail-ses cookbook

Integrates sendmail with Amazon SES.  This cookbooks duplicates this [doc](http://docs.aws.amazon.com/ses/latest/DeveloperGuide/sendmail.html) except rather than adding the configurations directly to the sendmail.mc file.  It is included as a separate file.

# Requirements

Requires sendmail to be installed.
Tested with the Amazon platform.

# Usage

Populate the sendmail attribute and include the default recipe `recipe[sendmail-ses::default]`.

# Attributes

* `sendmail_ses` a hash of attributes. REQUIRED
  * `username` ses username.  REQUIRED
  * `password` ses password.  REQUIRED
  * `domain` domain where email will be sent from.  REQUIRED
  * `port` tcp port. Default is 25
  * `test_user` SES verified user to send from.  IE <test_user>@<domain>
  * `test_email` Send a test email to the given address.
  * `aws_region` the AWS region to use - default is us-east-1

# Recipes

default - Handles all integration

# Author

Author:: TABLE XI (<sysadmin@tablexi.com>)

# Contributors

- [csimons](https://github.com/csimons)
- [ianbamforth](http://github.com/ianbamforth)

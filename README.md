# sendmail-ses cookbook

Integrates sendmail with Amazon SES.  This cookbooks duplicates this [doc](http://docs.aws.amazon.com/ses/latest/DeveloperGuide/sendmail.html) except rather then adding the configurations directly to the sendmail.mc file.  It is included as a seperate file.

# Requirements

Requires sendmail to be installed.
Tested with the Amazon platform.

# Usage

Populate the sendmail attribute and include the default recipe `recipe[sendmail-ses::default]`.

# Attributes

* `username` ses username.  REQUIRED
* `password` ses password.  REQUIRED
* `domain` domain where email will be sent from.  REQUIRED
* `port` tcp port. Default is 25
* `test_email` if you would like a test email sent after configuration is complete.

# Recipes

default - Handles all integration

# Author

Author:: TABLE XI (<sysadmin@tablexi.com>)

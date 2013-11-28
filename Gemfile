source "http://rubygems.org"

gem 'chef'
# Berkshelf > 2.0.0 has ignores --skip-dependencies argument
gem 'berkshelf'

group :dev do
  gem "strainer",
    '>= 2'
  gem 'foodcritic',
    '~> 1.7.0'
  gem "chefspec",
    :git => "git://github.com/acrmp/chefspec.git"
  gem "fauxhai"
  gem 'gherkin',
    '= 2.11.6' # http://stackoverflow.com/a/15855623
end

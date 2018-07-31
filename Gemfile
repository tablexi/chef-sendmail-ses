source 'https://rubygems.org'

ruby File.open(File.expand_path('.ruby-version', File.dirname(__FILE__))) { |f| f.read.chomp }

gem 'berkshelf'
gem 'chef', '~> 14'

group :ci do
  gem 'bump'
  gem 'github_changelog_generator'
end

group :dev do
  gem 'chefspec'
  gem 'foodcritic'
  gem 'rubocop'
  gem 'stove'
end

group :guard do
  gem 'guard'
  gem 'guard-foodcritic'
  gem 'guard-kitchen'
  gem 'guard-rspec'
  gem 'guard-rubocop'
  gem 'ruby_gntp'
end

group :kitchen do
  gem 'chef-zero'
  gem 'kitchen-docker'
  gem 'kitchen-ec2'
  gem 'kitchen-transport-rsync'
  gem 'test-kitchen'
end

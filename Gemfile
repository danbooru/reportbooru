source 'https://rubygems.org'

gem 'dotenv-rails', :require => "dotenv/rails-now"
gem 'rails', '~> 4.2.0'
gem 'whenever'
gem 'capistrano'
gem 'redis'
gem 'aws-sdk', '~> 2'
gem 'memoist'

group :production do
  gem 'unicorn', :platforms => :ruby
  gem 'capistrano3-unicorn', :require => false
  gem 'capistrano-bundler'
  gem 'capistrano-rbenv'
  gem 'capistrano-deploytags', '~> 1.0.0', require: false
end

# Gemfile
source "https://rubygems.org"

ruby "~> 3.3"

gem "rails",  "~> 8.1.2"
gem "bootsnap", require: false
gem "pg",     "~> 1.5"

# Karafka is the Rails-native Kafka consumer framework.
# It manages partition assignment, offset commits, concurrency,
# and the consumer lifecycle — things we'd otherwise build manually.
gem "karafka", "~> 2.3"

group :development, :test do
  gem "rspec-rails",       "~> 8.0"
  gem "factory_bot_rails", "~> 6.4"
  gem "timecop",           "~> 0.9"
end

group :test do
  # Gives us a message bus stub — tests never need a live Kafka broker.
  gem "karafka-testing", "~> 2.3"
end

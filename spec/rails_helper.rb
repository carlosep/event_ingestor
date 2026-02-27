# spec/rails_helper.rb
require "spec_helper"
require File.expand_path("../config/environment", __dir__)
require "rspec/rails"
require "karafka/testing/rspec/helpers"
require "timecop"

RSpec.configure do |config|
  Dir[Rails.root.join("spec/support/**/*.rb")].each { |f| require f }
  config.include Karafka::Testing::RSpec::Helpers

  # Roll back DB changes after each test using transactions.
  # Faster than truncation and safe for unit tests (no extra threads).
  config.use_transactional_fixtures = true

  config.infer_spec_type_from_file_location!
end

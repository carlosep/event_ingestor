ENV["RAILS_ENV"] ||= "test"

require "spec_helper"

unless defined?(Rails) && Rails.application
  require File.expand_path("../config/environment", __dir__)
end

require "rspec/rails"
require "karafka/testing/rspec/helpers"
require "timecop"

Dir[Rails.root.join("spec/support/**/*.rb")].each { |f| require f }

RSpec.configure do |config|
  config.include Karafka::Testing::RSpec::Helpers, type: :consumer

  config.include(Module.new do
    def karafka_consumer_for(topic)
      _karafka_consumer_for(topic.to_s)
    end

    def produce(message)
      _karafka_produce(message.nil? ? nil : message.to_json)
    end
  end, type: :consumer)

  config.before(:suite) do
    Karafka::App.routes.draw do
      topic :events do
        consumer EventsConsumer
        dead_letter_queue(topic: "events.dlq", max_retries: 3)
      end
    end if Karafka::App.routes.empty?
  end

  config.use_transactional_fixtures = true
  config.infer_spec_type_from_file_location!
end

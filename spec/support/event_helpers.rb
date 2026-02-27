module EventHelpers
  def build_raw_event(overrides = {})
    {
      "event_id"    => SecureRandom.uuid,
      "user_id"     => "user_1",
      "type"        => "page_view",
      "occurred_at" => "2024-06-15T12:00:00Z",
      "props"       => { "page" => "/home" }
    }.merge(overrides.stringify_keys)
  end
end

RSpec.configure do |config|
  config.include EventHelpers
end

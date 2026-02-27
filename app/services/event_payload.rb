class EventPayload
  attr_reader :event_id, :user_id, :type, :occurred_at, :props

  REQUIRED_FIELDS = %w[event_id user_id type occurred_at].freeze

  class InvalidPayloadError < StandardError; end

  def self.parse(raw)
    new(raw)
  end

  def initialize(raw)
    validate!(raw)

    @event_id    = raw["event_id"].to_s.strip
    @user_id     = raw["user_id"].to_s.strip
    @type        = raw["type"].to_s.strip
    @occurred_at = parse_time!(raw["occurred_at"])
    @props       = raw.fetch("props", {}) || {}
  end

  private

  def validate!(raw)
    raise InvalidPayloadError, "payload must be a Hash, got #{raw.class}" unless raw.is_a?(Hash)

    missing = REQUIRED_FIELDS.reject { |f| raw[f].present? }
    raise InvalidPayloadError, "missing required fields: #{missing.join(', ')}" if missing.any?
  end

  def parse_time!(value)
    Time.iso8601(value.to_s)
  rescue ArgumentError, TypeError
    raise InvalidPayloadError,
          "occurred_at '#{value}' is not a valid ISO8601 timestamp"
  end
end

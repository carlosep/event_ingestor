class EventsConsumer < ApplicationConsumer
  BACKPRESSURE_PAUSE_MS = 5_000

  # Each Kafka message represents a single event.
  # The HTTP ingest layer (POST /events) is responsible for
  # splitting list payloads into individual messages before producing.
  def consume
    messages.each do |message|
      process(message)
    end
  end

  private

  def process(message)
    payload = parse(message)
    return if payload.nil?

    result = EventPersistenceService.new(payload).call
    result == :duplicate ? log_duplicate(payload) : log_persisted(payload)
  rescue ActiveRecord::StatementInvalid, PG::Error => e
    handle_backpressure(e, message)
    raise
  end

  def parse(message)
    EventPayload.parse(message.payload)
  rescue EventPayload::InvalidPayloadError => e
    route_to_dlq(message, e)
    nil
  end

  def route_to_dlq(message, error)
    Rails.logger.error(
      "[EventsConsumer] Invalid payload routed to DLQ " \
      "partition=#{message.partition} offset=#{message.offset} " \
      "error=#{error.message}"
    )
  end

  def handle_backpressure(error, message)
    Rails.logger.error(
      "[EventsConsumer] Transient error, pausing partition #{message.partition} " \
      "for #{BACKPRESSURE_PAUSE_MS}ms — #{error.class}: #{error.message}"
    )
    pause(BACKPRESSURE_PAUSE_MS)
  end

  def log_persisted(payload)
    Rails.logger.debug("[EventsConsumer] Persisted event_id=#{payload.event_id}")
  end

  def log_duplicate(payload)
    Rails.logger.info("[EventsConsumer] Duplicate skipped event_id=#{payload.event_id}")
  end
end

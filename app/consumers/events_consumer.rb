class EventsConsumer < ApplicationConsumer
  BACKPRESSURE_PAUSE_MS = 5_000

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
    # Invalid payloads are routed to the DLQ immediately without retrying.
    #
    # No retry:
    #   A structurally invalid message will never become valid no matter how
    #   many times we retry it. Retrying would permanently block the partition
    #   since Kafka preserves message order. Every subsequent valid message
    #   behind it would be stuck waiting.
    #
    # We handle this logic ourselves instead of relying solely on Karafka’s
    # built-in DLQ configured in karafka.rb with max_retries: 3 to prevent
    # messages with invalid payloads from consuming consecutive retries and
    # eventually being routed to the DLQ.
    # By rescuing InvalidPayloadError and returning nil, the message is skipped
    # immediately without burning retry attempts or pausing the partition. The
    # built-in DLQ remains in place as a safety net for unexpected errors that
    # are not explicitly handled.

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

    # pause stops Karafka from polling this partition for BACKPRESSURE_PAUSE_MS
    # milliseconds. Two things are important about how this works:
    #   1. No rebalance: the partition stays assigned to this consumer instance.
    #      Other partitions and other consumer instances are unaffected.
    #      This is a targeted pause, not a full consumer shutdown.
    #   2. No data loss: we call pause BEFORE raising. The raise propagates
    #      out of consume, which means Karafka does NOT commit the offset.
    #      After the pause expires, Kafka redelivers the batch from the last
    #      committed offset and we retry automatically.
    # Without pause, a tight retry loop would hammer an already degraded
    # database with no breathing room to recover.
    pause(BACKPRESSURE_PAUSE_MS)
  end

  def log_persisted(payload)
    Rails.logger.debug("[EventsConsumer] Persisted event_id=#{payload.event_id}")
  end

  def log_duplicate(payload)
    Rails.logger.info("[EventsConsumer] Duplicate skipped event_id=#{payload.event_id}")
  end
end

class EventPersistenceService
  def initialize(payload)
    @payload = payload
  end

  # @return [:persisted, :duplicate]
  def call
    ActiveRecord::Base.transaction do
      ProcessedEvent.create!(
        event_id:    @payload.event_id,
        user_id:     @payload.user_id,
        event_type:  @payload.type,
        props:       @payload.props,
        occurred_at: @payload.occurred_at
      )

      DailyMetric.increment!(
        user_id:    @payload.user_id,
        # We derive the day from occurred_at in UTC to make counts are consistent
        # regardless of where consumer instances are deployed geographically.
        day:        @payload.occurred_at.utc.to_date,
        event_type: @payload.type
      )
    end

    :persisted
  rescue ActiveRecord::RecordNotUnique
    # Idempotency is enforced by the unique index on processed_events.event_id.
    # This rescue handles two scenarios:
    #   1. Kafka at-least-once delivery: the broker can redeliver a message
    #      after a consumer restart or rebalance. The second delivery hits this
    #      rescue and returns :duplicate with no writes performed.
    #   2. Race condition: two consumer threads can both pass the uniqueness
    #      check before either commits. The second one to hit the DB is caught
    #      here by the unique index constraint.
    # In both cases the correct behaviour is identical: skip silently.
    :duplicate
  end
end

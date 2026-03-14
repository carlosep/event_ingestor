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
        day:        @payload.occurred_at.utc.to_date,
        event_type: @payload.type
      )
    end

    :persisted
  rescue ActiveRecord::RecordNotUnique
    :duplicate
  end
end

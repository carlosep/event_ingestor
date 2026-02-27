class DailyMetric < ApplicationRecord
  validates :user_id,     presence: true
  validates :day,         presence: true
  validates :event_type,  presence: true
  validates :event_count, numericality: { greater_than_or_equal_to: 0 }

  scope :for_user,     ->(uid)      { where(user_id: uid) }
  scope :between_days, ->(from, to) { where(day: from..to) }

  # Atomically increments the counter for a (user_id, day, event_type) triple.
  #
  # Compiles to a single SQL statement:
  #
  #   INSERT INTO daily_metrics (user_id, day, event_type, event_count, ...)
  #   VALUES ($1, $2, $3, 1, ...)
  #   ON CONFLICT (user_id, day, event_type)
  #   DO UPDATE SET
  #     event_count = daily_metrics.event_count + EXCLUDED.event_count,
  #     updated_at  = NOW()
  #
  # One round-trip. No SELECT. No application-level lock.
  # Postgres executes the check-and-increment atomically.
  def self.increment!(user_id:, day:, event_type:)
    upsert_all(
      [{ user_id: user_id, day: day, event_type: event_type, event_count: 1,
         created_at: Time.current, updated_at: Time.current }],
      unique_by:    :index_daily_metrics_on_user_id_and_day_and_event_type,
      on_duplicate: Arel.sql(
        "event_count = daily_metrics.event_count + EXCLUDED.event_count, " \
        "updated_at  = NOW()"
      )
    )
  end
end

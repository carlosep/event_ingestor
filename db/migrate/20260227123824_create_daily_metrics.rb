class CreateDailyMetrics < ActiveRecord::Migration[8.1]
  def change
    create_table :daily_metrics do |t|
      t.string  :user_id,     null: false
      t.date    :day,         null: false
      t.string  :event_type,  null: false
      t.integer :event_count, null: false, default: 0

      t.timestamps
    end

    # Three-column unique index — this is the conflict target for the upsert
    # in DailyMetric.increment! and also the primary lookup index for the
    # read API querying by user + day range + event type.
    add_index :daily_metrics, [:user_id, :day, :event_type], unique: true
  end
end

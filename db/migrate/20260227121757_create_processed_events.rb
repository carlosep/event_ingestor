class CreateProcessedEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :processed_events do |t|
      # event_id is a UUID that comes with the event payload.
      # It's our dedup key — a duplicate INSERT on this column
      # raises RecordNotUnique, which is our idempotency gate.
      t.string      :event_id,   null: false
      t.string      :user_id,    null: false
      t.string      :event_type, null: false
      t.jsonb       :props,      default: {}
      t.timestamptz :occurred_at, null: false
      t.timestamptz :ingested_at, null: false, default: -> { "NOW()" }
    end

    # Dedup constraint — the application catches violations from this.
    add_index :processed_events, :event_id, unique: true

    # Supports the read API: WHERE user_id = $1 AND occurred_at::date BETWEEN $2 AND $3
    # Also used by any backfill job recomputing daily_metrics from raw events.
    add_index :processed_events, [:user_id, :occurred_at]
  end
end

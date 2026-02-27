# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_02_27_123824) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "daily_metrics", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.date "day", null: false
    t.integer "event_count", default: 0, null: false
    t.string "event_type", null: false
    t.datetime "updated_at", null: false
    t.string "user_id", null: false
    t.index ["user_id", "day", "event_type"], name: "index_daily_metrics_on_user_id_and_day_and_event_type", unique: true
  end

  create_table "processed_events", force: :cascade do |t|
    t.string "event_id", null: false
    t.string "event_type", null: false
    t.timestamptz "ingested_at", default: -> { "now()" }, null: false
    t.timestamptz "occurred_at", null: false
    t.jsonb "props", default: {}
    t.string "user_id", null: false
    t.index ["event_id"], name: "index_processed_events_on_event_id", unique: true
    t.index ["user_id", "occurred_at"], name: "index_processed_events_on_user_id_and_occurred_at"
  end
end

require "rails_helper"

RSpec.describe EventsConsumer, type: :consumer do
  subject(:consumer) { karafka_consumer_for(:events) }

  def publish(overrides = {})
    produce(build_raw_event(overrides))
    consumer.consume
  end

  # ── happy path ───────────────────────────────────────────────────────────────

  describe "a valid new event" do
    it "persists to processed_events" do
      expect { publish }.to change(ProcessedEvent, :count).by(1)
    end

    it "creates a DailyMetric entry" do
      expect { publish }.to change(DailyMetric, :count).by(1)
    end

    it "creates the metric with the correct dimensions" do
      publish("user_id" => "alice", "type" => "page_view", "occurred_at" => "2024-06-15T10:00:00Z")
      expect(DailyMetric.find_by(
        user_id:    "alice",
        day:        Date.new(2024, 6, 15),
        event_type: "page_view"
      ).event_count).to eq(1)
    end
  end

  # ── event type dimension ──────────────────────────────────────────────────────

  describe "different event types" do
    it "creates separate counters per event type" do
      publish("user_id" => "alice", "type" => "page_view",    "occurred_at" => "2024-06-15T10:00:00Z")
      publish("user_id" => "alice", "type" => "button_click", "occurred_at" => "2024-06-15T10:00:00Z")

      expect(DailyMetric.find_by(user_id: "alice", day: Date.new(2024, 6, 15), event_type: "page_view").event_count).to eq(1)
      expect(DailyMetric.find_by(user_id: "alice", day: Date.new(2024, 6, 15), event_type: "button_click").event_count).to eq(1)
    end
  end

  # ── idempotency ───────────────────────────────────────────────────────────────

  describe "duplicate events" do
    let(:uuid) { SecureRandom.uuid }

    it "does not create a second ProcessedEvent" do
      2.times { publish("event_id" => uuid) }
      expect(ProcessedEvent.where(event_id: uuid).count).to eq(1)
    end

    it "does not increment the counter on the second delivery" do
      2.times do
        publish(
          "event_id"     => uuid,
          "user_id"      => "alice",
          "type"         => "page_view",
          "occurred_at"  => "2024-06-15T10:00:00Z"
        )
      end
      expect(DailyMetric.find_by(
        user_id:    "alice",
        day:        Date.new(2024, 6, 15),
        event_type: "page_view"
      ).event_count).to eq(1)
    end

    it "handles two copies of the same event in one batch" do
      raw = build_raw_event("event_id" => uuid)
      produce(raw)
      produce(raw)
      consumer.consume
      expect(ProcessedEvent.where(event_id: uuid).count).to eq(1)
    end
  end

  # ── batch processing ──────────────────────────────────────────────────────────

  describe "a batch of distinct events" do
    it "persists all of them" do
      5.times { produce(build_raw_event) }
      consumer.consume
      expect(ProcessedEvent.count).to eq(5)
    end

    it "accumulates counts for the same user and event type" do
      3.times do
        produce(build_raw_event(
          "user_id"     => "alice",
          "type"        => "page_view",
          "occurred_at" => "2024-06-15T10:00:00Z"
        ))
      end
      consumer.consume
      expect(DailyMetric.find_by(
        user_id:    "alice",
        day:        Date.new(2024, 6, 15),
        event_type: "page_view"
      ).event_count).to eq(3)
    end
  end

  # ── day boundary ──────────────────────────────────────────────────────────────

  describe "day boundary handling" do
    it "puts 23:59:59 UTC on day N, not day N+1" do
      publish("user_id" => "alice", "occurred_at" => "2024-06-14T23:59:59Z")
      expect(DailyMetric.find_by(user_id: "alice", day: Date.new(2024, 6, 14))).to be_present
      expect(DailyMetric.find_by(user_id: "alice", day: Date.new(2024, 6, 15))).to be_nil
    end

    it "splits a batch spanning midnight into the correct buckets" do
      produce(build_raw_event("user_id" => "alice", "type" => "page_view", "occurred_at" => "2024-06-14T23:59:00Z"))
      produce(build_raw_event("user_id" => "alice", "type" => "page_view", "occurred_at" => "2024-06-15T00:01:00Z"))
      consumer.consume

      expect(DailyMetric.find_by(user_id: "alice", day: Date.new(2024, 6, 14), event_type: "page_view").event_count).to eq(1)
      expect(DailyMetric.find_by(user_id: "alice", day: Date.new(2024, 6, 15), event_type: "page_view").event_count).to eq(1)
    end
  end

  # ── invalid payloads ──────────────────────────────────────────────────────────

  describe "invalid payloads" do
    it "does not crash when a required field is missing" do
      expect { publish(build_raw_event.except("event_id")) }.not_to raise_error
    end

    it "does not persist an invalid event" do
      produce(build_raw_event.except("user_id"))
      consumer.consume
      expect(ProcessedEvent.count).to eq(0)
    end

    it "does not crash on a nil payload" do
      produce(nil)
      expect { consumer.consume }.not_to raise_error
    end

    it "continues processing valid messages after an invalid one in the same batch" do
      good_uuid = SecureRandom.uuid
      produce(build_raw_event.except("event_id"))
      produce(build_raw_event("event_id" => good_uuid))
      consumer.consume
      expect(ProcessedEvent.find_by(event_id: good_uuid)).to be_present
    end
  end

  # ── backpressure ──────────────────────────────────────────────────────────────

  describe "transient DB error" do
    before do
      allow(ProcessedEvent).to receive(:create!).and_raise(ActiveRecord::StatementInvalid, "connection lost")
      allow(consumer).to receive(:pause)
    end

    it "pauses the partition with the configured timeout" do
      produce(build_raw_event)
      expect { consumer.consume }.to raise_error(ActiveRecord::StatementInvalid)
      expect(consumer).to have_received(:pause).with(EventsConsumer::BACKPRESSURE_PAUSE_MS)
    end

    it "re-raises so Karafka does not commit the offset" do
      produce(build_raw_event)
      expect { consumer.consume }.to raise_error(ActiveRecord::StatementInvalid)
    end
  end
end

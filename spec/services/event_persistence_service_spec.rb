# spec/services/event_persistence_service_spec.rb
require "rails_helper"

RSpec.describe EventPersistenceService do
  let(:payload) do
    EventPayload.parse(build_raw_event(
      "user_id"     => "alice",
      "type"        => "page_view",
      "occurred_at" => "2024-06-15T10:00:00Z"
    ))
  end

  subject(:service) { described_class.new(payload) }

  # ── happy path ───────────────────────────────────────────────────────────────

  describe "#call — new event" do
    it "returns :persisted" do
      expect(service.call).to eq(:persisted)
    end

    it "creates a ProcessedEvent row" do
      expect { service.call }.to change(ProcessedEvent, :count).by(1)
    end

    it "stores the correct attributes on ProcessedEvent" do
      service.call
      record = ProcessedEvent.last
      expect(record.event_id).to   eq(payload.event_id)
      expect(record.user_id).to    eq("alice")
      expect(record.event_type).to eq("page_view")
      expect(record.occurred_at).to be_within(1.second).of(Time.utc(2024, 6, 15, 10, 0, 0))
    end

    it "creates a DailyMetric row" do
      expect { service.call }.to change(DailyMetric, :count).by(1)
    end

    it "sets the daily count to 1" do
      service.call
      metric = DailyMetric.find_by(user_id: "alice", day: Date.new(2024, 6, 15), event_type: "page_view")
      expect(metric.event_count).to eq(1)
    end
  end

  # ── day bucketing ─────────────────────────────────────────────────────────────

  describe "day bucketing" do
    it "uses the UTC date of occurred_at, not the local server date" do
      # 23:30 UTC on June 14 could be June 15 in some timezones.
      # We always want the UTC date.
      late_payload = EventPayload.parse(build_raw_event(
        "user_id"     => "bob",
        "occurred_at" => "2024-06-14T23:30:00Z"
      ))
      described_class.new(late_payload).call

      expect(DailyMetric.find_by(user_id: "bob", day: Date.new(2024, 6, 14))).to be_present
      expect(DailyMetric.find_by(user_id: "bob", day: Date.new(2024, 6, 15))).to be_nil
    end
  end

  # ── event type dimension ──────────────────────────────────────────────────────

  describe "event type dimension" do
    it "creates separate counters for different event types on the same day" do
      described_class.new(EventPayload.parse(build_raw_event(
        "user_id" => "alice", "type" => "page_view",    "occurred_at" => "2024-06-15T10:00:00Z"
      ))).call
      described_class.new(EventPayload.parse(build_raw_event(
        "user_id" => "alice", "type" => "button_click", "occurred_at" => "2024-06-15T10:00:00Z"
      ))).call

      expect(DailyMetric.find_by(user_id: "alice", day: Date.new(2024, 6, 15), event_type: "page_view").event_count).to eq(1)
      expect(DailyMetric.find_by(user_id: "alice", day: Date.new(2024, 6, 15), event_type: "button_click").event_count).to eq(1)
    end
  end

  # ── idempotency ───────────────────────────────────────────────────────────────

  describe "#call — duplicate event" do
    before { service.call }

    it "returns :duplicate" do
      expect(service.call).to eq(:duplicate)
    end

    it "does not create a second ProcessedEvent" do
      expect { service.call }.not_to change(ProcessedEvent, :count)
    end

    it "does not increment the DailyMetric counter" do
      expect { service.call }.not_to change {
        DailyMetric.find_by(
          user_id:    "alice",
          day:        Date.new(2024, 6, 15),
          event_type: "page_view"
        )&.event_count
      }
    end
  end

  # ── counter accumulation ──────────────────────────────────────────────────────

  describe "multiple distinct events" do
    it "increments the counter for each new event" do
      3.times do
        described_class.new(EventPayload.parse(build_raw_event(
          "user_id"     => "alice",
          "type"        => "page_view",
          "occurred_at" => "2024-06-15T10:00:00Z"
        ))).call
      end

      expect(DailyMetric.find_by(
        user_id:    "alice",
        day:        Date.new(2024, 6, 15),
        event_type: "page_view"
      ).event_count).to eq(3)
    end
  end

  # ── transaction atomicity ─────────────────────────────────────────────────────

  describe "when DailyMetric.increment! raises after ProcessedEvent is inserted" do
    before do
      allow(DailyMetric).to receive(:increment!).and_raise(ActiveRecord::StatementInvalid, "DB error")
    end

    it "rolls back the ProcessedEvent insert" do
      expect { service.call rescue nil }.not_to change(ProcessedEvent, :count)
    end

    it "propagates the error to the caller" do
      expect { service.call }.to raise_error(ActiveRecord::StatementInvalid)
    end
  end
end

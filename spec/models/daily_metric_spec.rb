require "rails_helper"

RSpec.describe DailyMetric do
  describe ".increment!" do
    let(:user_id)    { "alice" }
    let(:day)        { Date.new(2024, 6, 15) }
    let(:event_type) { "page_view" }

    context "when no row exists yet" do
      it "creates a row with event_count 1" do
        described_class.increment!(user_id: user_id, day: day, event_type: event_type)
        expect(described_class.find_by(user_id: user_id, day: day, event_type: event_type).event_count).to eq(1)
      end
    end

    context "when a row already exists" do
      before { described_class.increment!(user_id: user_id, day: day, event_type: event_type) }

      it "does not create a duplicate row" do
        expect { described_class.increment!(user_id: user_id, day: day, event_type: event_type) }
          .not_to change(described_class, :count)
      end

      it "adds 1 to the existing count" do
        described_class.increment!(user_id: user_id, day: day, event_type: event_type)
        expect(described_class.find_by(user_id: user_id, day: day, event_type: event_type).event_count).to eq(2)
      end

      it "accumulates correctly over many calls" do
        9.times { described_class.increment!(user_id: user_id, day: day, event_type: event_type) }
        expect(described_class.find_by(user_id: user_id, day: day, event_type: event_type).event_count).to eq(10)
      end
    end

    context "with different event types for the same user and day" do
      it "keeps counters independent per event type" do
        described_class.increment!(user_id: user_id, day: day, event_type: "page_view")
        described_class.increment!(user_id: user_id, day: day, event_type: "page_view")
        described_class.increment!(user_id: user_id, day: day, event_type: "button_click")

        expect(described_class.find_by(user_id: user_id, day: day, event_type: "page_view").event_count).to eq(2)
        expect(described_class.find_by(user_id: user_id, day: day, event_type: "button_click").event_count).to eq(1)
      end
    end

    context "with different users on the same day and event type" do
      it "keeps counters independent per user" do
        described_class.increment!(user_id: "alice", day: day, event_type: event_type)
        described_class.increment!(user_id: "alice", day: day, event_type: event_type)
        described_class.increment!(user_id: "bob",   day: day, event_type: event_type)

        expect(described_class.find_by(user_id: "alice", day: day, event_type: event_type).event_count).to eq(2)
        expect(described_class.find_by(user_id: "bob",   day: day, event_type: event_type).event_count).to eq(1)
      end
    end

    context "with the same user and event type across different days" do
      it "keeps counters independent per day" do
        described_class.increment!(user_id: user_id, day: Date.new(2024, 6, 14), event_type: event_type)
        described_class.increment!(user_id: user_id, day: Date.new(2024, 6, 14), event_type: event_type)
        described_class.increment!(user_id: user_id, day: Date.new(2024, 6, 15), event_type: event_type)

        expect(described_class.find_by(user_id: user_id, day: Date.new(2024, 6, 14), event_type: event_type).event_count).to eq(2)
        expect(described_class.find_by(user_id: user_id, day: Date.new(2024, 6, 15), event_type: event_type).event_count).to eq(1)
      end
    end
  end
end

require "rails_helper"

RSpec.describe ProcessedEvent, type: :model do
  describe "validations" do
    it "is valid with all required attributes" do
      event = ProcessedEvent.new(
        event_id:    SecureRandom.uuid,
        user_id:     "user_1",
        event_type:  "page_view",
        occurred_at: Time.utc(2024, 6, 15, 10, 0, 0)
      )
      expect(event).to be_valid
    end

    %w[event_id user_id event_type occurred_at].each do |field|
      it "is invalid without #{field}" do
        event = ProcessedEvent.new(
          event_id:    SecureRandom.uuid,
          user_id:     "user_1",
          event_type:  "page_view",
          occurred_at: Time.utc(2024, 6, 15, 10, 0, 0)
        )
        event.send(:"#{field}=", nil)
        expect(event).not_to be_valid
      end
    end
  end
end

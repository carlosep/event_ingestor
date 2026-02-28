require "rails_helper"

RSpec.describe EventPayload do
  describe ".parse" do

    # ── valid payload ──────────────────────────────────────────────────────────

    context "with a valid payload" do
      subject(:payload) { described_class.parse(build_raw_event) }

      it "parses event_id as a string" do
        expect(payload.event_id).to be_a(String).and be_present
      end

      it "parses user_id" do
        expect(described_class.parse(build_raw_event("user_id" => "alice")).user_id).to eq("alice")
      end

      it "parses type" do
        expect(described_class.parse(build_raw_event("type" => "button_click")).type).to eq("button_click")
      end

      it "parses occurred_at into a Time object" do
        expect(payload.occurred_at).to be_a(Time)
      end

      it "preserves the UTC value of occurred_at" do
        p = described_class.parse(build_raw_event("occurred_at" => "2024-06-15T08:30:00Z"))
        expect(p.occurred_at).to eq(Time.utc(2024, 6, 15, 8, 30, 0))
      end

      it "preserves props when present" do
        p = described_class.parse(build_raw_event("props" => { "ref" => "email" }))
        expect(p.props).to eq("ref" => "email")
      end

      it "defaults props to {} when the key is absent" do
        p = described_class.parse(build_raw_event.except("props"))
        expect(p.props).to eq({})
      end

      it "defaults props to {} when the value is nil" do
        p = described_class.parse(build_raw_event("props" => nil))
        expect(p.props).to eq({})
      end
    end

    # ── missing / blank required fields ───────────────────────────────────────

    context "with missing or blank required fields" do
      %w[event_id user_id type occurred_at].each do |field|
        it "raises InvalidPayloadError when #{field} is missing" do
          expect { described_class.parse(build_raw_event.except(field)) }
            .to raise_error(EventPayload::InvalidPayloadError, /#{field}/)
        end

        it "raises InvalidPayloadError when #{field} is blank" do
          expect { described_class.parse(build_raw_event(field => "")) }
            .to raise_error(EventPayload::InvalidPayloadError)
        end
      end
    end

    # ── occurred_at edge cases ─────────────────────────────────────────────────

    context "with a malformed occurred_at" do
      it "raises on a non-ISO8601 string" do
        expect { described_class.parse(build_raw_event("occurred_at" => "15-06-2024")) }
          .to raise_error(EventPayload::InvalidPayloadError, /ISO8601/)
      end

      it "raises on a Unix timestamp integer" do
        expect { described_class.parse(build_raw_event("occurred_at" => 1_718_445_600)) }
          .to raise_error(EventPayload::InvalidPayloadError, /ISO8601/)
      end

      it "raises on a free text string" do
        expect { described_class.parse(build_raw_event("occurred_at" => "yesterday")) }
          .to raise_error(EventPayload::InvalidPayloadError, /ISO8601/)
      end
    end

    # ── non-hash payloads ──────────────────────────────────────────────────────

    context "with a non-hash payload" do
      it "raises on a plain string" do
        expect { described_class.parse("raw string") }
          .to raise_error(EventPayload::InvalidPayloadError, /must be a Hash/)
      end

      it "raises on nil" do
        expect { described_class.parse(nil) }
          .to raise_error(EventPayload::InvalidPayloadError)
      end

      it "raises on an array" do
        expect { described_class.parse([]) }
          .to raise_error(EventPayload::InvalidPayloadError, /must be a Hash/)
      end
    end
  end
end

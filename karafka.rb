class KarafkaApp < Karafka::App
  setup do |config|
    # With auto-commit on, Kafka advances the offset on a timer regardless
    # of whether processing succeeded. A crash mid-batch would silently
    # skip messages — they'd never be redelivered. With it off, Karafka
    # only commits after #consume returns successfully. A crash means
    # redelivery, and idempotency handles the duplicate safely.
    config.kafka = {
      "bootstrap.servers": ENV.fetch("KAFKA_BOOTSTRAP_SERVERS", "localhost:9092"),
      "group.id":          ENV.fetch("KAFKA_CONSUMER_GROUP", "event_ingestor"),
      "auto.offset.reset": "earliest",
      "enable.auto.commit": false
    }

    config.max_messages = Integer(ENV.fetch("KAFKA_MAX_MESSAGES", "100"))
    config.concurrency  = Integer(ENV.fetch("KARAFKA_CONCURRENCY", "5"))
  end

  routes.draw do
    topic :events do
      consumer EventsConsumer
      dead_letter_queue(topic: "events.dlq", max_retries: 3)
    end
  end
end

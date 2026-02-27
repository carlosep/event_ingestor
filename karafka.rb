class KarafkaApp < Karafka::App
  setup do |config|
    config.kafka = {
      "bootstrap.servers": ENV.fetch("KAFKA_BOOTSTRAP_SERVERS", "localhost:9092"),
      "group.id":          ENV.fetch("KAFKA_CONSUMER_GROUP", "event_ingestor"),
      "auto.offset.reset": "earliest",

      # Only commit offsets after #consume returns successfully.
      # If the consumer crashes mid-batch, Kafka redelivers from the last
      # committed offset — idempotency in EventPersistenceService handles
      # the redelivery safely.
      "enable.auto.commit": false
    }

    config.max_messages = Integer(ENV.fetch("KAFKA_MAX_MESSAGES", "100"))
    config.concurrency  = Integer(ENV.fetch("KARAFKA_CONCURRENCY", "5"))
    config.deserializer = Karafka::Serialization::Json::Deserializer.new
  end

  routes.draw do
    topic :events do
      consumer EventsConsumer
      dead_letter_queue(topic: "events.dlq", max_retries: 3)
    end
  end
end

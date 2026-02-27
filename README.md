# Event Ingestor

A Rails API service that ingests user events and provides near-real-time activity counts per user and day, powering dashboards and alerting systems.

## Overview

Events are accepted via HTTP, produced to Kafka, and consumed into PostgreSQL where counts are pre-aggregated by user, day, and event type. The architecture is designed for write-heavy ingest with fast read lookups.

## Requirements

- Ruby 3.3+
- Rails 8.1
- PostgreSQL 14+
- Kafka

## Setup

Clone the repository and install dependencies:
```bash
bundle install
```

Create and migrate the database:
```bash
bundle exec rails db:create db:migrate
```

## Configuration

The following environment variables are available:

| Variable | Default | Description |
|---|---|---|
| `DATABASE_URL` | configured in `database.yml` | PostgreSQL connection string |
| `KAFKA_BOOTSTRAP_SERVERS` | `localhost:9092` | Kafka broker addresses |
| `KAFKA_CONSUMER_GROUP` | `event_ingestor` | Consumer group ID |
| `KAFKA_MAX_MESSAGES` | `100` | Messages fetched per poll |
| `KARAFKA_CONCURRENCY` | `5` | Consumer worker threads |

## Running the application

Start the Rails server:
```bash
bundle exec rails server
```

Start the Kafka consumer:
```bash
bundle exec karafka server
```

## Running the tests
```bash
bundle exec rspec
```

## API

### Ingest

| Method | Path | Description |
|---|---|---|
| `POST` | `/events` | Accepts a single event or a list of events |

### Metrics

| Method | Path | Description |
|---|---|---|
| `GET` | `/metrics/daily` | Event counts for a user over a date range |
| `GET` | `/metrics/today` | Event counts for a user today |

#### Event payload
```json
{
  "event_id": "550e8400-e29b-41d4-a716-446655440000",
  "user_id": "user_123",
  "type": "page_view",
  "occurred_at": "2024-06-15T10:00:00Z",
  "props": {
    "page": "/dashboard"
  }
}
```

`props` is optional. All other fields are required.

## Architecture
```
POST /events
     │
     ▼
HTTP Ingest Layer
     │  produces one Kafka message per event
     ▼
Kafka topic: events
     │
     ▼
Kafka Consumer (EventsConsumer)
     │
     ├── EventPayload        validates and parses the raw message
     │
     └── EventPersistenceService
              │
              ├── processed_events    raw event log + idempotency ledger
              │
              └── daily_metrics       pre-aggregated counts by user, day, event type
```

## Project Structure
```
app/
  consumers/
    events_consumer.rb          # Kafka consumer
  models/
    processed_event.rb          # Raw event audit log
    daily_metric.rb             # Pre-aggregated read model
  services/
    event_payload.rb            # Payload validation and parsing
    event_persistence_service.rb # Transactional write to Postgres
db/
  migrate/
    ..._create_processed_events.rb
    ..._create_daily_metrics.rb
spec/
  consumers/
    events_consumer_spec.rb
  models/
    daily_metric_spec.rb
    processed_event_spec.rb
  services/
    event_payload_spec.rb
    event_persistence_service_spec.rb
  support/
    event_helpers.rb
```
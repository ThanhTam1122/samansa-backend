# Movie Store — Subscription Management API

A Ruby on Rails API that manages Apple In-App Purchase subscriptions for a video streaming service. Handles the full subscription lifecycle: provisional start from the client, activation/renewal/cancellation via Apple Server-to-Server Webhooks.

## Architecture Overview

```
┌──────────┐   POST /api/subscriptions    ┌──────────────┐
│  Client   │ ──────────────────────────► │              │
│   App     │   (after Apple purchase)    │  Rails API   │
└──────────┘                              │              │
                                          │  ┌────────┐  │     ┌─────────┐
┌──────────┐   POST /api/webhooks/apple   │  │ MySQL  │  │     │ Swagger │
│  Apple    │ ──────────────────────────► │  │   DB   │  │     │   UI    │
│  Server   │   (PURCHASE/RENEW/CANCEL)   │  └────────┘  │     │/api-docs│
└──────────┘                              └──────────────┘     └─────────┘
```

## Subscription Lifecycle

```
  Client purchase
        │
        ▼
    ┌─────────┐   Apple PURCHASE    ┌────────┐   Apple RENEW    ┌────────┐
    │ pending  │ ─────────────────► │ active │ ───────────────► │ active │
    └─────────┘                     └────────┘                  └────────┘
    (not viewable)                  (viewable)                  (viewable, new period)
                                        │
                                        │ Apple CANCEL
                                        ▼
                                   ┌───────────┐
                                   │ cancelled │
                                   └───────────┘
                                   (viewable until expires_date)
```

- **pending** — Client reported a purchase, awaiting Apple webhook confirmation. Not viewable.
- **active** — Apple confirmed via PURCHASE or RENEW webhook. Viewable.
- **cancelled** — Apple sent a CANCEL webhook. Still viewable until `expires_date`.

## API Endpoints

| Method | Path | Description |
|--------|------|-------------|
| `POST` | `/api/subscriptions` | Provisionally start a subscription after client-side purchase |
| `GET` | `/api/subscriptions/:user_id` | Get all subscriptions for a user |
| `POST` | `/api/webhooks/apple` | Receive Apple Server-to-Server Notifications |

Interactive API documentation is available at `/api-docs` (Swagger UI).

### POST /api/subscriptions

Called by the client app after Apple In-App Purchase completes.

```json
{
  "subscription": {
    "user_id": "user_123",
    "transaction_id": "txn_abc",
    "product_id": "com.samansa.subscription.monthly"
  }
}
```

Returns `201 Created` for new subscriptions, `200 OK` if transaction_id already exists (idempotent).

### POST /api/webhooks/apple

Receives Apple Server Notifications for subscription lifecycle events.

```json
{
  "webhook": {
    "notification_uuid": "notif_001",
    "type": "PURCHASE",
    "transaction_id": "txn_abc",
    "product_id": "com.samansa.subscription.monthly",
    "amount": "3.9",
    "currency": "USD",
    "purchase_date": "2025-10-01T12:00:00Z",
    "expires_date": "2025-11-01T12:00:00Z"
  }
}
```

Supported types: `PURCHASE` (activate), `RENEW` (extend period), `CANCEL` (mark cancelled).

## Database Design

### subscriptions

The main table tracking each user's subscription state.

| Column | Type | Description |
|--------|------|-------------|
| `user_id` | string | User identifier |
| `transaction_id` | string | Apple transaction ID (unique) |
| `product_id` | string | Subscription plan ID |
| `status` | string | `pending`, `active`, or `cancelled` |
| `purchase_date` | datetime | Current period start (set by webhook) |
| `expires_date` | datetime | Current period end / next renewal (set by webhook) |
| `amount` | decimal | Charge amount |
| `currency` | string | Currency code |

Indexes: unique on `transaction_id`, composite on `(user_id, status)`, on `expires_date`.

### subscription_events

Immutable audit log of every Apple webhook notification received.

| Column | Type | Description |
|--------|------|-------------|
| `notification_uuid` | string | Apple notification ID (unique, for idempotency) |
| `transaction_id` | string | Links to subscription |
| `event_type` | string | `PURCHASE`, `RENEW`, or `CANCEL` |
| `product_id` | string | Plan ID |
| `amount` / `currency` | decimal/string | Charge details |
| `purchase_date` / `expires_date` | datetime | Period info |
| `processed_at` | datetime | When the event was processed |

## Design Decisions

### Idempotency

- **Client endpoint**: Duplicate `POST /api/subscriptions` with the same `transaction_id` returns the existing record instead of creating a duplicate. Enforced by a DB unique index.
- **Webhook endpoint**: Duplicate `notification_uuid` is detected and safely returns `200 OK` with `"already_processed"`. Both application-level check and DB unique constraint guard against race conditions.

### Two-Phase Activation

Subscriptions start as `pending` (not viewable) when created from the client. They only become `active` (viewable) when Apple confirms via a PURCHASE webhook. This prevents users from gaining access before payment is verified by Apple.

### Grace Period on Cancellation

Cancelled subscriptions remain viewable until `expires_date`. The `viewable?` method checks both status and expiry, so users retain access for the period they've already paid for.

### Event Sourcing (Audit Trail)

Every webhook notification is recorded in `subscription_events` as an immutable log. This enables:
- Debugging payment issues
- Revenue analytics (amount/currency per event)
- Reconstructing subscription history

### Transactional Consistency

Webhook processing uses `ActiveRecord::Base.transaction` to ensure the event record and subscription state update are atomic — either both succeed or neither does.

### Scalability Considerations

- Database indexes on frequently queried columns (`user_id`, `transaction_id`, `expires_date`)
- Composite index on `(user_id, status)` for efficient user subscription lookups
- Stateless API design — can be horizontally scaled behind a load balancer
- DB-level unique constraints handle race conditions without distributed locks

## Tech Stack

- **Ruby on Rails** 8.1 (API mode)
- **MySQL** 8.0 (via Docker)
- **rswag** for Swagger/OpenAPI documentation

## Getting Started

### Prerequisites

- Ruby 3.4+
- Docker & Docker Compose
- `libmysqlclient-dev` (`sudo apt-get install libmysqlclient-dev`)

### Setup

```bash
# Start MySQL
cd movie-store
docker compose up -d

# Install dependencies
bundle install

# Create and migrate database
bin/rails db:create db:migrate

# Start the server
bin/rails server
```

### Generate Swagger Documentation

```bash
bundle exec rake rswag:specs:swaggerize
```

Then visit http://localhost:3000/api-docs for the interactive API documentation.

### Run Tests

```bash
bundle exec rspec
```

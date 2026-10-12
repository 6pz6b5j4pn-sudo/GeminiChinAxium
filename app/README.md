# Event Service

A simple HTTP service for asynchronous event processing with idempotency guarantees.

## What This Service Does

The service provides an HTTP API to accept events, process them asynchronously in the background, and track their status. It implements basic idempotency to prevent duplicate processing of events with the same ID.

**Key Features:**
- Accept events via HTTP POST
- Queue events for background processing
- Track event status (accepted/processed)
- Health and readiness checks
- Graceful shutdown handling

## Running Locally

### Prerequisites
- Go 1.22 or later

### Start the service

```bash
go run ./...
```

The service will start on port 8080 by default.

### Configuration

The service can be configured via environment variables:

| Variable | Default | Description |
|----------|---------|-------------|
| `PORT` | `8080` | HTTP server port |
| `ENV` | `dev` | Environment (dev/staging/prod) |
| `PROCESSING_DELAY_MS` | `1000` | Simulated processing delay in milliseconds |

Example with custom configuration:

```bash
PORT=3000 ENV=staging PROCESSING_DELAY_MS=500 go run ./...
```

## Frontend Dashboard

A minimal web dashboard is available at the root URL when you start the service:

```
http://127.0.0.1:8080/
```

The dashboard provides:
- Real-time service health and worker status monitoring
- Interactive form to submit new events
- Live event list showing all events and their status (accepted/processed)
- Auto-refresh every 2 seconds to display updates

Simply open the URL in your browser to visualize and interact with the event service.

## Running with Docker

The [Dockerfile](Dockerfile) is a multi-stage build: it compiles a static binary with the Go toolchain and copies it into a minimal Alpine image that runs as a non-root user. Configuration uses the same environment variables as above, and the container has a `HEALTHCHECK` on `/health`.

```bash
docker build -t event-service .
docker run --rm -p 8080:8080 -e ENV=staging -e PROCESSING_DELAY_MS=500 event-service
```

If you change `PORT`, map it accordingly, e.g. `-e PORT=3000 -p 3000:3000`. On Apple Silicon, add `--platform linux/amd64` when building an image for ECS Fargate.

## Improvements Made

Changes made to the original starter code:

- **Race-free idempotency**: `Store.SaveIfAbsent` checks and saves atomically, so two concurrent requests with the same `event_id` can no longer both be accepted.
- **Snapshot reads**: `Store.List` returns sorted copies instead of live pointers, removing a data race with the worker and making output stable.
- **Non-blocking enqueue**: when the 100-slot queue is full (or the worker is stopping), `POST /events` rolls the event back and returns `503` instead of hanging the request.
- **Graceful shutdown**: on SIGTERM/SIGINT the HTTP server stops accepting requests (`http.Server.Shutdown`), then the worker drains queued events (10s limit). `Worker.Stop` is idempotent and `running` is an atomic flag (previously a data race).
- **Server hardening**: read/write/idle timeouts and a 1 MiB request body limit.
- **Startup errors**: a failed listen (e.g. port in use) now exits non-zero instead of the process waiting forever for a signal.
- **Config validation**: negative `PROCESSING_DELAY_MS` is treated as 0.
- **Containerization and infrastructure as code**: Dockerfile and Terraform (see the repository root README).

Verified with `go vet`, a `-race` build, and a manual run covering 202, 409, processing and graceful shutdown. There are still no automated tests.

## API Endpoints

### GET /

Serves the frontend dashboard HTML page.

### GET /events

Lists all events currently stored in the service.

**Response:**
```json
[
  {
    "event_id": "evt_123",
    "payload": {
      "any": "data"
    },
    "status": "processed"
  }
]
```

Always returns `200 OK` with an array of events.

### POST /events

Accepts an event for processing.

**Request:**
```json
{
  "event_id": "evt_123",
  "payload": {
    "any": "data",
    "goes": "here"
  }
}
```

**Responses:**
- `202 Accepted` - Event accepted and queued for processing
- `409 Conflict` - Event with this ID already exists
- `400 Bad Request` - Invalid request body or missing event_id (bodies over 1 MiB are rejected)
- `503 Service Unavailable` - Processing queue is full or the service is shutting down; retry later with the same `event_id`

### GET /health

Returns service health status.

**Response:**
```json
{
  "status": "ok",
  "uptime": "5m32s"
}
```

Always returns `200 OK`.

### GET /ready

Returns readiness status (whether the background worker is running).

**Response (Ready):**
```json
{
  "status": "ready",
  "ready": true
}
```
Returns `200 OK` when ready.

**Response (Not Ready):**
```json
{
  "status": "not ready",
  "ready": false
}
```
Returns `503 Service Unavailable` when not ready.

## Testing the Service

### Using Insomnia (Recommended)

An Insomnia collection is included for easy API testing:

1. Install [Insomnia](https://insomnia.rest/download) if you haven't already
2. Import the collection: `File > Import` and select `insomnia-collection.json`
3. The collection includes pre-configured requests for all endpoints:
   - `GET /health` - Check service health
   - `GET /ready` - Check worker readiness
   - `POST /events - New Event` - Create a new event (returns 202)
   - `POST /events - Duplicate Event` - Test idempotency (returns 409)
   - `POST /events - Event 2, 3` - Additional test events
   - `POST /events - Missing event_id` - Test validation (returns 400)
   - `POST /events - Invalid JSON` - Test error handling (returns 400)

The base URL is configured as `http://127.0.0.1:8080`.

### Using curl

**Accept an event:**
```bash
curl -X POST http://127.0.0.1:8080/events \
  -H "Content-Type: application/json" \
  -d '{"event_id": "evt_001", "payload": {"test": "data"}}'
```

**Try to send the same event again (should return 409):**
```bash
curl -X POST http://127.0.0.1:8080/events \
  -H "Content-Type: application/json" \
  -d '{"event_id": "evt_001", "payload": {"test": "data"}}'
```

**Check health:**
```bash
curl http://127.0.0.1:8080/health
```

**Check readiness:**
```bash
curl http://127.0.0.1:8080/ready
```

**Stop the service:**
Press `Ctrl+C` in the terminal where the service is running.

## Project Structure

```
event-service/
├── go.mod                      # Go module definition
├── main.go                     # Application entry point, signal handling
├── Dockerfile                  # Multi-stage container build
├── insomnia-collection.json    # Insomnia API client collection
├── internal/
│   ├── app/
│   │   └── app.go             # HTTP server, handlers, config
│   ├── model/
│   │   └── model.go           # Request/response types, event model
│   ├── store/
│   │   └── store.go           # In-memory idempotency store
│   └── worker/
│       └── worker.go          # Background event processor
└── README.md
```

## Important Note: Not Production-Ready

**This service is intentionally not production-ready.** It is designed as starter code for a technical assessment.

### Known Limitations:
- **No persistence**: All event state is stored in memory and will be lost on restart
- **Single instance only**: State is per-instance, so run exactly one replica
- **No structured logging**: Uses basic `log.Printf` statements
- **No metrics or observability**: No instrumentation for monitoring
- **Limited error handling**: Basic error responses without detailed error types
- **No rate limiting**: No protection against traffic spikes
- **No authentication/authorization**: Endpoints are completely open
- **No dead letter queue**: Failed events are not captured or retried
- **No automated tests**

Candidates are expected to identify and address these gaps as part of the technical assessment.

# Skilloper API

Go REST API backend for the Skilloper platform.

## Prerequisites

- Go 1.24+
- Git (for cloning)

## Setup

### Using Makefile (Recommended)

```bash
# From project root
make help          # See all available commands
make install-deps  # Install dependencies
make start-api     # Start API server
```

### Manual Setup

```bash
# Navigate to API directory
cd skilloper-api

# Install dependencies
go mod tidy

# Run in development mode
go run main.go
```

**Server runs on:** `http://localhost:8080`


## How to Run

### Development Mode
```bash
# Standard run
go run main.go

# With custom port
PORT=9000 go run main.go

# With custom database
DATABASE_PATH=custom.db go run main.go

# With auto-restart (install air first: go install github.com/cosmtrek/air@latest)
air
```

### Production Mode
```bash
# Build binary
go build -o skilloper-api

# Run binary
./skilloper-api

# Run with environment variables
PORT=8080 DATABASE_PATH=production.db ./skilloper-api
```

## Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `PORT` | `8080` | Server port |
| `DATABASE_PATH` | `skilloper.db` | SQLite database file path |
| `ALLOWED_ORIGINS` | http://localhost:3000,3001 + 127.0.0.1 variants | Comma-separated CORS origins |

## API Reference

- **[API Endpoints](../docs/api-endpoints.md)** - Complete endpoint reference
- **[Quiz Schema](../docs/quiz-schema.md)** - Quiz import formats

## Database

- **Type:** SQLite
- **File:** `skilloper.db` (auto-created)
- **Schema:** Auto-migrated on startup using GORM


## Testing

```bash
# Run all tests
go test ./...

# Run tests with coverage
go test -cover ./...

# Run specific package tests
go test ./internal/services/
```

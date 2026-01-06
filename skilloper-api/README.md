# Skilloper API

Go REST API backend for the Skilloper platform - a clean, maintainable service for managing programming skill assessments.

## Description

Provides endpoints for managing programming skill assessments with support for practice and exam modes. Features include:

- **Question Shuffling**: Randomized answer options for each request
- **Multiple Question Types**: Single-choice and multiple-choice questions
- **Alternative Content**: Randomized question texts and answer options for variety
- **Configurable Option Limits**: Quiz-level control over maximum options per question
- **Comprehensive Question Management**: Code syntax support with explanations
- **Quiz History**: Track quiz attempts with detailed answer history per device

## Prerequisites

- Go 1.19 or higher
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

The API supports environment-based configuration:

| Variable | Default | Description |
|----------|---------|-------------|
| `PORT` | `8080` | Server port |
| `DATABASE_PATH` | `skilloper.db` | SQLite database file path |
| `FRONTEND_URL_1` | `http://localhost:3000` | Allowed CORS origin |
| `FRONTEND_URL_2` | `http://127.0.0.1:3000` | Allowed CORS origin |
| `FRONTEND_URL_3` | `http://localhost:3001` | Allowed CORS origin |
| `FRONTEND_URL_4` | `http://127.0.0.1:3001` | Allowed CORS origin |

### Example
```bash
# Custom configuration
export PORT=9000
export DATABASE_PATH=/data/skilloper.db
export FRONTEND_URL_1=https://skilloper.example.com
go run main.go
```

## API Reference

For complete API documentation, see:
- **[API Endpoints](../docs/api-endpoints.md)** - Complete endpoint reference with examples
- **[Quiz Schema](../docs/quiz-schema.md)** - JSON schema for creating quizzes

## Quick Start

Create a simple quiz:

```bash
curl -X POST http://localhost:8080/api/v1/quizzes \
  -H "Content-Type: application/json" \
  -d '{
    "title": "JavaScript Basics",
    "type": "practice",
    "questions": [
      {
        "question": "What is the correct way to declare a variable?",
        "options": ["var x", "let x", "const x", "variable x"],
        "correctAnswer": 1,
        "explanation": "let is the modern way to declare variables in JavaScript"
      }
    ]
  }'
```

For complete schema documentation with all features, see [Quiz Schema](../docs/quiz-schema.md).

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

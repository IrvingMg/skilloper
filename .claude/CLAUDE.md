# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Skilloper is a self-training platform for developers featuring interactive quizzes with two modes:
- **Practice Mode**: Immediate feedback with explanations after each question
- **Exam Mode**: Simulates interview conditions with results shown at the end

The project consists of:
- `skilloper-api/` - Go REST API backend (Gin + GORM + SQLite/PostgreSQL)
- `skilloper_app/` - Flutter web application frontend

## Common Commands

### Quick Start
```bash
make install-deps    # Install all dependencies
make start           # Start both services in background (logs: api.log, app.log)
make stop            # Stop both services
```

### API Development (skilloper-api/)
```bash
make start-api                          # Start server on :8080 with auto env loading
go test ./internal/services/            # Run specific package tests
go test -run TestQuizService ./...      # Run single test by name
go test -cover ./...                    # Run with coverage
```

### Flutter App Development (skilloper_app/)
```bash
make start-app                          # Development with hot reload on :3001
flutter test test/widget_test.dart      # Run single test file
```

### Code Quality
```bash
make verify          # Run all linting (golangci-lint, govulncheck, dart analyze)
make fix             # Auto-fix all code issues
make test            # Run all tests (Go + Flutter)
```

## Architecture

### Backend (Go)
Layered architecture with dependency injection:
```
handlers/ (HTTP) → services/ (Business Logic) → models/ + database/
```

Key patterns:
- Custom `AppError` type with error codes in `internal/errors/`
- Services injected into handlers via constructor
- Request/Response DTOs separate from domain models
- GORM auto-migration for database schema
- Zap structured logging

### Frontend (Flutter)
- Stateful widgets managing local state (no external state management)
- Bottom navigation with `IndexedStack` for tab state preservation
- Singleton `ApiService` and `AuthService` for HTTP and auth
- Material 3 theme system in `theme/`

### Data Flow

**Practice Mode**: User selects answer → `POST /answers` → Instant validation → Show explanation

**Exam Mode**: `POST /attempts` (start) → Collect answers locally → `PATCH /attempts/{id}` → Server validates and scores

### Security Model
- Correct answers never sent to client during quiz play
- Server validates all answers (prevents score tampering)
- Frontend shuffles option display order; backend selects alternative text variants
- Rate limiting with dual-layer protection (IP-only + IP:username)

## Code Style

- **Minimal comments**: Code should be self-documenting. Only add comments for non-obvious logic.
- **No over-engineering**: Keep solutions simple and focused on the task at hand.
- **Consistent patterns**: Follow existing patterns in the codebase.

## Question Types

- **Single Choice**: Radio buttons, uses `correctAnswer: int` (0-indexed)
- **Multiple Choice**: Checkboxes, uses `correct_answers: []int` (0-indexed array)

## Environment Variables (API)

Copy `.env.example` to `.env` for local development. Required variables:
- `JWT_SECRET` - Secret key for signing JWT tokens
- `ADMIN_USERNAME` / `ADMIN_PASSWORD` - Initial admin credentials

Key optional variables:
- `APP_ENV` - `development` (auto-loads .env) or `production`
- `DB_DRIVER` - `sqlite` (default) or `postgres`
- `DATABASE_URL` - PostgreSQL connection URL (required when DB_DRIVER=postgres)
- `RATE_LIMIT_ENABLED` - Enable rate limiting (requires Redis)

## Documentation

- `docs/api-endpoints.md` - Complete API reference with curl examples
- `docs/quiz-schema.md` - Quiz import formats (Simple JSON, CSV, Internal JSON)

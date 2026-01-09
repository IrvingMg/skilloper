# Skilloper API

Go REST API backend for the Skilloper platform.

## Prerequisites

- Go 1.24+
- Git (for cloning)
- PostgreSQL (for production) or SQLite (for development)

## Quick Start

```bash
# From repo root
make install-deps  # Install dependencies
cp skilloper-api/.env.example skilloper-api/.env
# Edit .env with your values
make start-api     # Start API server
```

## Configuration

Copy `.env.example` to `.env` and configure:

| Variable | Default | Description |
|----------|---------|-------------|
| `APP_ENV` | - | Set to `development` to load .env file |
| `PORT` | `8080` | Server port |
| `DB_DRIVER` | `sqlite` | Database driver (`sqlite` or `postgres`) |
| `DATABASE_PATH` | `skilloper.db` | SQLite file path |
| `DATABASE_URL` | - | PostgreSQL connection URL (required when DB_DRIVER=postgres) |
| `JWT_SECRET` | **Required** | Secret key for signing JWT tokens |
| `JWT_EXPIRY` | `24` | Token expiry time in hours |
| `ADMIN_USERNAME` | **Required** | Admin username (6-30 chars) |
| `ADMIN_PASSWORD` | **Required** | Admin password (8-72 chars) |
| `ALLOWED_ORIGINS` | localhost:3000,3001 | Comma-separated CORS origins |

## Development

### Using Makefile (Recommended)

```bash
# From repo root
make help          # See all available commands
make start-api     # Start API server (sets APP_ENV=development)
make start         # Start both API and Flutter app
make stop          # Stop all services
```

### Manual Setup

```bash
cd skilloper-api
cp .env.example .env
# Edit .env with your values
APP_ENV=development go run main.go

# With auto-restart (install air first)
APP_ENV=development air
```

## Production

### With PostgreSQL

```bash
APP_ENV=production \
DB_DRIVER=postgres \
DATABASE_URL="postgres://user:pass@host:5432/skilloper?sslmode=require" \
JWT_SECRET="your-production-secret" \
ADMIN_USERNAME="admin" \
ADMIN_PASSWORD="SecurePass123!" \
./skilloper-api
```

### Build

```bash
go build -o skilloper-api
```

## Database

- **Development:** SQLite (auto-created as `skilloper.db`)
- **Production:** PostgreSQL (with connection pooling: 25 max, 10 idle)
- **Schema:** Auto-migrated on startup using GORM

## API Reference

- **[API Endpoints](../docs/api-endpoints.md)** - Complete endpoint reference
- **[Quiz Schema](../docs/quiz-schema.md)** - Quiz import formats

## Testing

```bash
go test ./...              # Run all tests
go test -cover ./...       # With coverage
go test ./internal/services/  # Specific package
```

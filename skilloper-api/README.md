# Skilloper API

Go REST API backend for the Skilloper platform.

## Prerequisites

- Go 1.24+
- PostgreSQL (for production) or SQLite (for development)
- Redis (optional, required when rate limiting is enabled)

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
| `RATE_LIMIT_ENABLED` | `false` | Enable rate limiting (requires Redis) |
| `RATE_LIMIT_LOGIN` | `5-M` | Login rate limit per IP:username |
| `RATE_LIMIT_REGISTER` | `3-M` | Register rate limit per IP:username |
| `RATE_LIMIT_API` | `120-M` | API rate limit per authenticated user |
| `REDIS_URL` | - | Redis URL (required when rate limiting enabled) |
| `REDIS_KEY_PREFIX` | `skilloper` | Redis key prefix for rate limits |
| `TLS_CERT_FILE` | - | Path to TLS certificate (enables HTTPS with TLS_KEY_FILE) |
| `TLS_KEY_FILE` | - | Path to TLS private key (enables HTTPS with TLS_CERT_FILE) |
| `LOG_LEVEL` | `info` | Logging level: `debug`, `info`, `warn`, `error` |
| `STATIC_MODE` | `embed` | Static file mode: `embed` (in binary), `dir` (STATIC_DIR), `none` (API only) |
| `STATIC_DIR` | - | Path to Flutter web build (required when STATIC_MODE=dir) |

**Rate limit format:** `count-period` (e.g., `5-M` = 5 per minute). Periods: S (second), M (minute), H (hour), D (day). IP-only limits are automatically 3x the configured values.

## Development

### Using Makefile (Recommended)

```bash
# From repo root
make help          # See all available commands
make start-api     # Start API server (sets APP_ENV=development)
make start         # Start both API and Flutter app
make stop          # Stop all services
```

## Production

### With PostgreSQL, Rate Limiting, and TLS

```bash
APP_ENV=production \
DB_DRIVER=postgres \
DATABASE_URL="postgres://user:pass@host:5432/skilloper?sslmode=require" \
JWT_SECRET="your-production-secret" \
ADMIN_USERNAME="admin_user" \
ADMIN_PASSWORD="SecurePass123!" \
RATE_LIMIT_ENABLED=true \
REDIS_URL="redis://localhost:6379" \
TLS_CERT_FILE="/etc/letsencrypt/live/example.com/fullchain.pem" \
TLS_KEY_FILE="/etc/letsencrypt/live/example.com/privkey.pem" \
PORT=443 \
./app
```

**TLS:** When both `TLS_CERT_FILE` and `TLS_KEY_FILE` are set, the server runs HTTPS. Omit both for HTTP. Setting only one will cause the server to exit with an error.

### Build

```bash
go build -o app
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
# Using Makefile (from repo root)
make test-api              # Run Go tests

# Direct Go commands
go test ./...              # Run all tests
go test -cover ./...       # With coverage
go test ./internal/services/  # Specific package
```

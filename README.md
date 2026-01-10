# Skilloper

A self-training platform for developers to practice technical skills through interactive quizzes.

## Quick Start

### Prerequisites
- Go 1.24+
- Flutter SDK
- Make
- Docker (optional)

### Development

```bash
git clone https://github.com/irvingmg/skilloper.git
cd skilloper
make install-deps
cp skilloper-api/.env.example skilloper-api/.env
make start    # API on :8080, App on :3001
```

### Production

```bash
# Local binary (SQLite)
make run

# Docker (SQLite)
make run-docker

# Docker with PostgreSQL
DATABASE_URL='postgres://user:pass@host:5432/db' DB_DRIVER=postgres make run-docker
```

Run `make help` for all commands.

## Deployment

Single container/binary serving API + embedded Flutter frontend.

**Environment variables:**
- `DB_DRIVER` - `sqlite` (default) or `postgres`
- `DATABASE_URL` - PostgreSQL connection URL
- `JWT_SECRET` - JWT signing secret
- `ADMIN_USERNAME` / `ADMIN_PASSWORD` - Initial admin credentials
- `STATIC_MODE` - `embed` (default), `dir`, or `none`
- `STATIC_DIR` - Path to static files (required when `STATIC_MODE=dir`)

**Build:**
```bash
make build    # Builds Flutter + Go with embedded static
```

Static files are embedded in the binary by default. Use `STATIC_MODE=none` for API-only mode.

## Documentation

- [API Reference](docs/api-endpoints.md)
- [Quiz Import Formats](docs/quiz-schema.md)

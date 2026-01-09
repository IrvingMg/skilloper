.PHONY: help start start-api start-app install-deps clean-all stop

# Default environment variables (can be overridden: LOG_LEVEL=debug make start-api)
APP_ENV ?= development
LOG_LEVEL ?= info

help:
	@echo "Available targets:"
	@echo "  start        Start both API and Flutter app in background"
	@echo "  start-api    Start API server only"
	@echo "  start-app    Start Flutter app only"
	@echo "  install-deps Install dependencies"
	@echo "  clean-all    Remove database, binaries, and logs"
	@echo "  stop         Stop background processes"
	@echo ""
	@echo "Environment variables (with defaults):"
	@echo "  APP_ENV=$(APP_ENV)    development or production"
	@echo "  LOG_LEVEL=$(LOG_LEVEL)  debug, info, warn, error"
	@echo ""
	@echo "Examples:"
	@echo "  LOG_LEVEL=debug make start-api  # Enable verbose logging"
	@echo "  LOG_LEVEL=warn make start-api   # Production-like (security events only)"

install-deps:
	@echo "Installing dependencies..."
	cd skilloper-api && go mod tidy
	cd skilloper_app && flutter pub get

start-api:
	@echo "Starting API server on http://localhost:8080 (APP_ENV=$(APP_ENV), LOG_LEVEL=$(LOG_LEVEL))"
	cd skilloper-api && APP_ENV=$(APP_ENV) LOG_LEVEL=$(LOG_LEVEL) go run main.go

start-app:
	@echo "Starting Flutter app on http://localhost:3001"
	cd skilloper_app && flutter run -d chrome --web-port 3001

start:
	@echo "Starting both services in background..."
	@echo "API: http://localhost:8080 (APP_ENV=$(APP_ENV), LOG_LEVEL=$(LOG_LEVEL))"
	@echo "App: http://localhost:3001"
	@echo "Logs: api.log and app.log"
	@echo "Run 'make stop' to stop both services"
	cd skilloper-api && APP_ENV=$(APP_ENV) LOG_LEVEL=$(LOG_LEVEL) nohup go run main.go > ../api.log 2>&1 &
	cd skilloper_app && nohup flutter run -d chrome --web-port 3001 > ../app.log 2>&1 &
	@echo "Services started. Use 'make stop' to stop them."

stop:
	@echo "Stopping services..."
	@lsof -ti:8080 | xargs kill -9 2>/dev/null || true
	@lsof -ti:3001 | xargs kill -9 2>/dev/null || true
	@pkill -f "go run main.go" 2>/dev/null || true
	@pkill -f "flutter run" 2>/dev/null || true
	@echo "Services stopped."

clean-all:
	@echo "Cleaning up..."
	@rm -f skilloper-api/skilloper.db skilloper.db
	@rm -f skilloper-api/skilloper-api skilloper-api/main
	@rm -f api.log app.log nohup.out
	@cd skilloper_app && flutter clean
	@echo "Cleanup completed."
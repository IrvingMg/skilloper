.PHONY: help start start-api start-app install-deps clean-all stop \
        build build-app build-api run test \
        build-docker run-docker stop-docker \
        verify verify-api verify-app fix fix-api fix-app

# Default environment variables (can be overridden: LOG_LEVEL=debug make start-api)
APP_ENV ?= development
LOG_LEVEL ?= info

# Server port
PORT ?= 8080

# Docker variables
DOCKER_IMAGE ?= skilloper
DOCKER_TAG ?= latest

# Go tools path
GOBIN ?= $(shell go env GOPATH)/bin

# Build variables
API_URL ?= /api/v1

# ==============================================================================
# Help
# ==============================================================================
help:
	@echo "Available targets:"
	@echo ""
	@echo "Development:"
	@echo "  start        Start both API and Flutter app in background"
	@echo "  start-api    Start API server only"
	@echo "  start-app    Start Flutter app only"
	@echo "  install-deps Install dependencies"
	@echo "  stop         Stop background processes"
	@echo ""
	@echo "Code Quality:"
	@echo "  verify       Run all linting and analysis (Go + Flutter)"
	@echo "  verify-api   Run Go linting (golangci-lint + govulncheck)"
	@echo "  verify-app   Run Flutter analysis and format check"
	@echo "  fix          Auto-fix all code (Go + Flutter)"
	@echo "  fix-api      Auto-fix Go code (lint + format)"
	@echo "  fix-app      Auto-fix Flutter code (lint + format)"
	@echo ""
	@echo "Build & Test:"
	@echo "  build        Build Flutter and Go with embedded static"
	@echo "  build-app    Build Flutter web release"
	@echo "  build-api    Build Go binary (API only, defaults to STATIC_MODE=none)"
	@echo "  test         Run all tests"
	@echo ""
	@echo "Production (local):"
	@echo "  run          Build and run Go serving Flutter locally"
	@echo ""
	@echo "Docker:"
	@echo "  build-docker Build Docker image"
	@echo "  run-docker   Run Docker container"
	@echo "  stop-docker  Stop Docker container"
	@echo ""
	@echo "Cleanup:"
	@echo "  clean-all    Remove database, binaries, builds, and logs"
	@echo ""
	@echo "Variables:"
	@echo "  APP_ENV=$(APP_ENV)          development or production"
	@echo "  LOG_LEVEL=$(LOG_LEVEL)      debug, info, warn, error"
	@echo "  PORT=$(PORT)                Server port"
	@echo "  DOCKER_IMAGE=$(DOCKER_IMAGE)  Docker image name"
	@echo "  DOCKER_TAG=$(DOCKER_TAG)    Docker image tag"

# ==============================================================================
# Development
# ==============================================================================
install-deps:
	@echo "Installing dependencies..."
	cd skilloper-api && go mod tidy
	cd skilloper_app && flutter pub get
	@echo "Installing Go tools..."
	go install github.com/golangci/golangci-lint/v2/cmd/golangci-lint@latest
	go install golang.org/x/vuln/cmd/govulncheck@latest
	@echo "All dependencies installed!"

start-api:
	@echo "Starting API server on http://localhost:8080 (APP_ENV=$(APP_ENV), LOG_LEVEL=$(LOG_LEVEL))"
	cd skilloper-api && APP_ENV=$(APP_ENV) LOG_LEVEL=$(LOG_LEVEL) STATIC_MODE=none go run -tags noembed .

start-app:
	@echo "Starting Flutter app on http://localhost:3001"
	cd skilloper_app && flutter run -d chrome --web-port 3001

start:
	@echo "Starting both services in background..."
	@echo "API: http://localhost:8080 (APP_ENV=$(APP_ENV), LOG_LEVEL=$(LOG_LEVEL))"
	@echo "App: http://localhost:3001"
	@echo "Logs: api.log and app.log"
	@echo "Run 'make stop' to stop both services"
	cd skilloper-api && APP_ENV=$(APP_ENV) LOG_LEVEL=$(LOG_LEVEL) STATIC_MODE=none nohup go run -tags noembed . > ../api.log 2>&1 &
	cd skilloper_app && nohup flutter run -d chrome --web-port 3001 > ../app.log 2>&1 &
	@echo "Services started. Use 'make stop' to stop them."

stop:
	@echo "Stopping services..."
	@lsof -ti:8080 | xargs kill -9 2>/dev/null || true
	@lsof -ti:3001 | xargs kill -9 2>/dev/null || true
	@pkill -f "go run main.go" 2>/dev/null || true
	@pkill -f "flutter run" 2>/dev/null || true
	@pkill -f "build/skilloper-api" 2>/dev/null || true
	@pkill -f "build/skilloper" 2>/dev/null || true
	@echo "Services stopped."

# ==============================================================================
# Code Quality
# ==============================================================================
verify-api:
	@echo "Running Go code quality checks..."
	cd skilloper-api && $(GOBIN)/golangci-lint run ./...
	@echo "Running govulncheck..."
	cd skilloper-api && $(GOBIN)/govulncheck ./...
	@echo "Go checks passed!"

fix-api:
	@echo "Fixing Go code..."
	cd skilloper-api && $(GOBIN)/golangci-lint run --fix ./...
	@echo "Go code fixed!"

verify-app:
	@echo "Running Flutter analysis..."
	cd skilloper_app && dart analyze lib/ test/
	@echo "Checking Dart formatting..."
	cd skilloper_app && dart format --set-exit-if-changed lib/ test/
	@echo "Flutter checks passed!"

fix-app:
	@echo "Fixing Flutter code..."
	cd skilloper_app && dart fix --apply lib/
	cd skilloper_app && dart fix --apply test/
	cd skilloper_app && dart format lib/ test/
	@echo "Flutter code fixed!"

verify: verify-api verify-app
	@echo "All checks passed!"

fix: fix-api fix-app
	@echo "All code fixed!"

# ==============================================================================
# Build
# ==============================================================================
build-app:
	@echo "Building Flutter web app..."
	cd skilloper_app && flutter build web --release --dart-define=API_URL=$(API_URL)
	@echo "Flutter build complete: skilloper_app/build/web/"

build-api:
	@echo "Building Go binary (API only)..."
	@mkdir -p build
	cd skilloper-api && CGO_ENABLED=1 go build -tags noembed -ldflags="-w -s -X github.com/irvingmg/skilloper/skilloper-api/internal/config.DefaultStaticMode=none" -o ../build/skilloper-api .
	@echo "Go build complete: build/skilloper-api"

build: build-app
	@echo "Copying static files for embedding..."
	@rm -rf skilloper-api/static && cp -r skilloper_app/build/web skilloper-api/static
	@echo "Building Go binary with embedded static..."
	@mkdir -p build
	cd skilloper-api && CGO_ENABLED=1 go build -ldflags="-w -s" -o ../build/skilloper .
	@echo "Build complete!"

test:
	@echo "Running Go tests..."
	cd skilloper-api && go test -tags noembed ./...
	@echo "Running Flutter tests..."
	cd skilloper_app && flutter test
	@echo "All tests passed!"

# ==============================================================================
# Production (local)
# ==============================================================================
run: build
	@echo "Starting server at http://localhost:$(PORT)"
	cd build && \
		APP_ENV=production \
		DB_DRIVER="$${DB_DRIVER:-sqlite}" \
		DATABASE_URL="$${DATABASE_URL}" \
		JWT_SECRET="$${JWT_SECRET:-your-secret-key-min-32-characters!}" \
		ADMIN_USERNAME="$${ADMIN_USERNAME:-admin_user}" \
		ADMIN_PASSWORD="$${ADMIN_PASSWORD:-Admin123!}" \
		LOG_LEVEL=$(LOG_LEVEL) \
		PORT=$(PORT) \
		./skilloper

# ==============================================================================
# Docker
# ==============================================================================
build-docker:
	@echo "Building Docker image $(DOCKER_IMAGE):$(DOCKER_TAG)..."
	docker build -t $(DOCKER_IMAGE):$(DOCKER_TAG) .
	@echo "Docker image built successfully!"
	@docker images $(DOCKER_IMAGE):$(DOCKER_TAG)

run-docker: build-docker
	@docker rm -f skilloper 2>/dev/null || true
	@echo "Running container at http://localhost:$(PORT)"
	docker run -d \
		--name skilloper \
		-p $(PORT):8080 \
		-e DB_DRIVER="$${DB_DRIVER:-sqlite}" \
		-e DATABASE_URL="$${DATABASE_URL}" \
		-e LOG_LEVEL="$${LOG_LEVEL:-$(LOG_LEVEL)}" \
		-e JWT_SECRET="$${JWT_SECRET:-your-secret-key-min-32-characters!}" \
		-e ADMIN_USERNAME="$${ADMIN_USERNAME:-admin_user}" \
		-e ADMIN_PASSWORD="$${ADMIN_PASSWORD:-Admin123!}" \
		$(DOCKER_IMAGE):$(DOCKER_TAG)
	@echo "Container started. Use 'docker logs -f skilloper' to view logs."

stop-docker:
	@echo "Stopping Docker container..."
	docker stop skilloper 2>/dev/null || true
	docker rm skilloper 2>/dev/null || true
	@echo "Container stopped."

# ==============================================================================
# Cleanup
# ==============================================================================
clean-all:
	@echo "Cleaning up..."
	@rm -f skilloper-api/skilloper.db skilloper.db
	@rm -rf build
	@rm -rf skilloper-api/static
	@rm -f api.log app.log nohup.out
	@cd skilloper_app && flutter clean
	@echo "Cleanup completed."

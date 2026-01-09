.PHONY: help start start-api start-app install-deps clean-all stop \
        build build-app build-api run test \
        build-docker run-docker stop-docker \
        build-deploy

# Default environment variables (can be overridden: LOG_LEVEL=debug make start-api)
APP_ENV ?= development
LOG_LEVEL ?= info

# Server port
PORT ?= 8080

# Docker variables
DOCKER_IMAGE ?= skilloper
DOCKER_TAG ?= latest

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
	@echo "Build & Test:"
	@echo "  build        Build both API binary and Flutter web"
	@echo "  build-api    Build Go binary"
	@echo "  build-app    Build Flutter web release"
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
	@echo "Deployment:"
	@echo "  build-deploy Build static files for deployment"
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
	@pkill -f "build/skilloper" 2>/dev/null || true
	@echo "Services stopped."

# ==============================================================================
# Build
# ==============================================================================
build-app:
	@echo "Building Flutter web app..."
	cd skilloper_app && flutter build web --release --dart-define=API_URL=$(API_URL)
	@echo "Flutter build complete: skilloper_app/build/web/"

build-api:
	@echo "Building Go binary..."
	@mkdir -p build
	cd skilloper-api && CGO_ENABLED=1 go build -ldflags="-w -s" -o ../build/skilloper .
	@echo "Go build complete: build/skilloper"

build: build-app build-api
	@echo "Build complete!"

test:
	@echo "Running Go tests..."
	cd skilloper-api && go test ./...
	@echo "Running Flutter tests..."
	cd skilloper_app && flutter test
	@echo "All tests passed!"

# ==============================================================================
# Production (local)
# ==============================================================================
run: build
	@rm -rf skilloper-api/static && cp -r skilloper_app/build/web skilloper-api/static
	@echo "Starting server at http://localhost:$(PORT)"
	cd build && \
		APP_ENV=production \
		DB_DRIVER="$${DB_DRIVER:-sqlite}" \
		DATABASE_URL="$${DATABASE_URL}" \
		JWT_SECRET="$${JWT_SECRET:-your-secret-key-min-32-characters!}" \
		ADMIN_USERNAME="$${ADMIN_USERNAME:-admin_user}" \
		ADMIN_PASSWORD="$${ADMIN_PASSWORD:-Admin123!}" \
		LOG_LEVEL=$(LOG_LEVEL) \
		STATIC_DIR=../skilloper-api/static \
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
# Deployment
# ==============================================================================
build-deploy: build-app
	@echo "Preparing static files for deployment..."
	@rm -rf skilloper-api/static
	@cp -r skilloper_app/build/web skilloper-api/static
	@echo ""
	@echo "Deployment build complete: skilloper-api/static/"

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

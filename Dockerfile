# =============================================================================
# Stage 1: Build Flutter Web Application
# =============================================================================
FROM debian:bookworm-slim AS flutter-builder

RUN apt-get update && apt-get install -y --no-install-recommends \
    git curl unzip xz-utils ca-certificates \
    && rm -rf /var/lib/apt/lists/*

RUN useradd -m flutter
USER flutter

ENV FLUTTER_VERSION=3.35.3
ENV FLUTTER_HOME=/home/flutter/sdk
ENV PATH="${FLUTTER_HOME}/bin:${PATH}"

RUN git clone --depth 1 --branch ${FLUTTER_VERSION} https://github.com/flutter/flutter.git ${FLUTTER_HOME}

WORKDIR /home/flutter/app

COPY --chown=flutter:flutter skilloper_app/pubspec.* ./
RUN flutter pub get

COPY --chown=flutter:flutter skilloper_app/ ./

RUN flutter build web --release --dart-define=API_URL=/api/v1

# =============================================================================
# Stage 2: Build Go API Binary
# =============================================================================
FROM golang:1.24-alpine AS go-builder

RUN apk add --no-cache gcc musl-dev

WORKDIR /app

COPY skilloper-api/go.mod skilloper-api/go.sum ./
RUN go mod download

COPY skilloper-api/ ./

RUN CGO_ENABLED=1 GOOS=linux go build -ldflags="-w -s" -o skilloper .

# =============================================================================
# Stage 3: Runtime Image
# =============================================================================
FROM alpine:3.21

RUN apk add --no-cache ca-certificates tzdata

RUN addgroup -g 1000 skilloper && \
    adduser -D -u 1000 -G skilloper skilloper

WORKDIR /app

COPY --from=go-builder /app/skilloper .
COPY --from=flutter-builder /home/flutter/app/build/web ./static

RUN mkdir -p /app/data && chown -R skilloper:skilloper /app

USER skilloper

ENV PORT=8080 \
    STATIC_DIR=/app/static \
    APP_ENV=production \
    LOG_LEVEL=info \
    DB_DRIVER=sqlite \
    DATABASE_PATH=/app/data/skilloper.db

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget -qO- http://localhost:${PORT}/api/v1/health || exit 1

ENTRYPOINT ["./skilloper"]

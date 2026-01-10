#!/bin/bash
set -e

# Install Flutter
git clone --depth 1 --branch 3.35.3 https://github.com/flutter/flutter.git /tmp/flutter
export PATH="/tmp/flutter/bin:$PATH"

# Build Flutter web
cd skilloper_app
flutter pub get
flutter build web --release --dart-define=API_URL=/api/v1
cd ..

# Copy static files for embedding
rm -rf skilloper-api/static
cp -r skilloper_app/build/web skilloper-api/static

# Build Go binary with embedded static
cd skilloper-api
go mod tidy
go build -tags netgo -ldflags '-s -w' -o app .

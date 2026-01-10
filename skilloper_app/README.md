# Skilloper App

Flutter web application frontend for the Skilloper platform.

## Prerequisites

- Flutter SDK (with Dart 3.9+)
- Chrome/Edge browser (for web development)
- Skilloper API running on `http://localhost:8080`

## Setup

```bash
# Navigate to app directory
cd skilloper_app

# Install dependencies
flutter pub get

# Verify Flutter setup
flutter doctor
```

## How to Run

### Development Mode
```bash
# Run web app with hot reload
flutter run -d chrome --web-port 3001

# With custom API URL
flutter run -d chrome --web-port 3001 --dart-define=API_URL=https://your-api.com/api/v1
```

**App runs on:** `http://localhost:3001`
**Default API:** `http://localhost:8080/api/v1`

### Production Build
```bash
# Build optimized web bundle
flutter build web --release

# Output in build/web/ - deploy to web server
```

## Development

### Running Different Platforms
```bash
# Web (primary)
flutter run -d chrome --web-port 3001

# Android (future)
flutter run -d android

# iOS (future - macOS only)
flutter run -d ios
```

### Development Tools
```bash
# Hot reload (automatic in dev mode)
# Just save files and see changes instantly

# Run tests (from repo root)
make test-app

# Or directly
flutter test

# Code analysis
flutter analyze

# Format code
flutter format lib/
```

## Quiz Format

For creating quizzes, see [Quiz Schema](../docs/quiz-schema.md).

# Skilloper

A self-training platform for developers to practice technical skills through interactive quizzes with practice and exam modes.

## Architecture

```
skilloper/
├── skilloper-api/     # Go REST API backend
└── skilloper_app/     # Flutter web application
```

## Quick Start

### Prerequisites
- Go 1.24+ 
- Flutter SDK
- Git
- Make

### Setup & Run

```bash
# Clone repository
git clone https://github.com/irvingmg/skilloper.git
cd skilloper

# Install dependencies
make install-deps

# Start both services
make start

# Access the app at http://localhost:3001
# API runs on http://localhost:8080

# Stop services when done
make stop
```

## Documentation

- [API Documentation](skilloper-api/README.md) - Backend setup and endpoints
- [App Documentation](skilloper_app/README.md) - Frontend development guide

## Development

### Available Commands

Run `make help` to see all available commands.

### Development Features

Both components support hot reload for rapid development:
- **API**: Automatic restart on file changes
- **App**: Flutter hot reload for instant UI updates
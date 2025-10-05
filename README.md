# Skilloper

A self-training platform for developers to practice technical skills through interactive questionnaires. Features practice and exam modes to help prepare for coding interviews and assessments.

## Features

- **Practice Mode**: Get immediate feedback with explanations after each question
- **Exam Mode**: Simulate real interview conditions with results shown only at the end
- **Code Questions**: Beautiful syntax-highlighted programming questions with copy functionality
- **Import/Export**: Upload questionnaires from JSON/CSV files
- **Multi-Platform**: Web-focused with mobile support

## Architecture

```
skilloper/
├── skilloper-api/     # Go REST API backend
└── skilloper_app/     # Flutter web application
```

## Quick Start

### Prerequisites
- Go 1.19+ 
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

## Usage

1. **Access** the web app at `http://localhost:3001`
2. **Browse** available questionnaires on the home screen
3. **Choose** Practice mode (immediate feedback) or Exam mode (end results)
4. **Import** custom questionnaires via the Import tab
5. **Review** detailed results with explanations

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
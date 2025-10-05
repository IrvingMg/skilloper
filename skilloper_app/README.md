# Skilloper App

Flutter web application frontend for the Skilloper platform - delivers an interactive developer skills assessment experience.

## Description

Modern web interface for taking programming skill assessments with real-time feedback, code syntax highlighting, and responsive design. Features include:

- **Multiple Question Types**: Single-choice and multiple-choice questions with distinct UI
- **Randomized Content**: Fresh question and answer shuffling on each attempt
- **Alternative Content**: Varied question texts and answer options for repeated practice
- **Real-time Feedback**: Immediate explanations in practice mode
- **Exam Simulation**: Realistic interview conditions with delayed feedback

## Prerequisites

- Flutter SDK 3.0+
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

# Or run on any available device
flutter run
```

**App runs on:** `http://localhost:3001`

### Production Build
```bash
# Build optimized web bundle
flutter build web --release

# Output in build/web/ - deploy to web server
```

## How to Use

### Taking Assessments
1. **Browse** available questionnaires on the home screen
2. **Select** a questionnaire to start (content is shuffled fresh each time)
3. **Answer questions:**
   - **Single-choice**: Select one correct answer with radio buttons
   - **Multiple-choice**: Select multiple correct answers with checkboxes
4. **Get feedback:**
   - **Practice mode**: Immediate feedback with explanations
   - **Exam mode**: Review all answers at the end
5. **Review results** with detailed explanations and correct answer highlights

### Importing Questionnaires
1. **Navigate** to Import tab
2. **Upload** JSON or CSV files
3. **Files are processed** and added to available questionnaires

## Development Examples

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

# Run tests
flutter test

# Code analysis
flutter analyze

# Format code
flutter format lib/

# Generate app icons
flutter pub run flutter_launcher_icons:main
```

### Simple Questionnaire Example

```json
{
  "title": "React Basics",
  "description": "Test your React knowledge",
  "type": "practice",
  "questions": [
    {
      "question": "What hook is used for state management?",
      "options": ["useState", "useEffect", "useContext"],
      "correctAnswer": 0,
      "explanation": "useState is the primary hook for managing component state"
    }
  ]
}
```

For complete schema documentation with all features, see [Questionnaire Schema](../docs/questionnaire-schema.md).


## Questionnaire Format

For complete documentation on creating questionnaires, see [Questionnaire Schema](../docs/questionnaire-schema.md).

### Key Features for Users

- **Single-choice questions**: Use radio buttons for one correct answer
- **Multiple-choice questions**: Use checkboxes for multiple correct answers
- **Question shuffling**: Answer options randomize each time you take a quiz
- **Alternative content**: Questions and answers vary on repeat attempts
- **Code highlighting**: Programming code displays with syntax highlighting
- **Practice vs Exam modes**: Immediate feedback or delayed results
- **0-based Indexing**: Use 0, 1, 2... to indicate correct answers (programming convention)

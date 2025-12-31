# Questionnaire JSON Schema

This document defines the complete JSON schema for creating questionnaires in the Skilloper platform.

## Complete Schema

```json
{
  "title": "string (required)",
  "description": "string (optional)",
  "type": "practice|exam (optional, defaults to 'practice')",
  "max_options": "integer (optional, 2-8 range, defaults to 4)",
  "questions": [
    {
      "question_type": "single_choice|multiple_choice (optional, defaults to 'single_choice')",
      "question": "string (required)",
      "alternative_questions": ["string", "string"] (optional),
      "code": "string (optional)",
      "language": "string (optional)",
      "options": ["string", "string", "string"] (required),
      "alternative_options": ["string", "string"] (optional),
      "correctAnswer": "integer (required for single_choice, 0-based)",
      "correct_answers": [0, 1, 2] (required for multiple_choice, 0-based),
      "alternative_answers": ["string", "string"] (optional),
      "explanation": "string (optional)"
    }
  ]
}
```

## Field Reference

### Questionnaire Level

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `title` | string | Yes | Name of the questionnaire |
| `description` | string | No | Brief description of the questionnaire content |
| `type` | string | No | Assessment mode: `"practice"` (immediate feedback) or `"exam"` (delayed feedback). Defaults to `"practice"` |
| `max_options` | integer | No | Maximum answer options per question (2-8 range). Defaults to 4. Validates that no question exceeds this limit |

### Question Level

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `question_type` | string | No | `"single_choice"` (one correct answer) or `"multiple_choice"` (multiple correct answers). Defaults to `"single_choice"` |
| `question` | string | Yes | The main question text |
| `alternative_questions` | array | No | Alternative phrasings of the question for variety on repeat attempts |
| `code` | string | No | Code snippet to display with the question |
| `language` | string | No | Programming language for syntax highlighting (e.g., "javascript", "python", "go") |
| `options` | array | Yes | Answer choices (must not exceed `max_options`) |
| `alternative_options` | array | No | Additional answer options for shuffling variety |
| `correctAnswer` | integer | Yes* | **Required for single_choice.** 0-based index of correct option (0 = first option, 1 = second option, etc.) |
| `correct_answers` | array | Yes* | **Required for multiple_choice.** Array of 0-based indices of all correct options |
| `alternative_answers` | array | No | Alternative texts for correct answers to provide variety |
| `explanation` | string | No | Explanation shown after answering, describing why the answer is correct |

*Either `correctAnswer` or `correct_answers` is required depending on `question_type`

## Key Behaviors

- **0-based Indexing**: All answer indices use 0-based counting (0, 1, 2...) following programming conventions
- **Hybrid Shuffling for Variety**:
  - **Backend**: Randomly selects from `alternative_questions` and `alternative_answers` for text variety
  - **Frontend**: Shuffles option display order while mapping selections back to original indices
  - **Result**: Each quiz attempt feels different while maintaining correct server-side validation
- **Question Order**: Questions maintain their original order
- **Validation**: API returns detailed errors if limits are exceeded or required fields are missing
- **Duplicate Protection**: Server ignores duplicate question submissions in attempt completion

## Security Note

**Import vs API Response:**
- When **importing** a questionnaire, `correctAnswer`/`correct_answers` are **required** and stored securely
- When **fetching** a questionnaire via `GET /questionnaires/{id}`, these fields are **hidden** from the response
- Answer validation happens **server-side** to prevent submitting fake scores

See [api-endpoints.md](api-endpoints.md) for details on the secure answer validation flow.

## Examples

### Single Choice Question with Code
```json
{
  "title": "JavaScript Fundamentals",
  "description": "Test your JavaScript knowledge",
  "type": "practice",
  "max_options": 4,
  "questions": [
    {
      "question_type": "single_choice",
      "question": "What is the output of typeof null?",
      "alternative_questions": ["What does typeof null return?", "typeof null evaluates to what?"],
      "code": "console.log(typeof null);",
      "language": "javascript",
      "options": ["null", "undefined", "object", "boolean"],
      "alternative_options": ["string", "number"],
      "correctAnswer": 2,
      "alternative_answers": ["object type", "the object string"],
      "explanation": "typeof null returns \"object\" due to a JavaScript quirk"
    }
  ]
}
```

### Multiple Choice Question
```json
{
  "question_type": "multiple_choice",
  "question": "Which are valid JavaScript data types?",
  "options": ["string", "number", "boolean", "object"],
  "alternative_options": ["undefined", "symbol", "bigint"],
  "correct_answers": [0, 1, 2, 3],
  "explanation": "All listed options are valid JavaScript primitive and non-primitive types"
}
```

### Question with Option Limits
```json
{
  "title": "Quick Quiz",
  "description": "Short questions with limited options",
  "type": "practice",
  "max_options": 3,
  "questions": [
    {
      "question": "Which HTTP status code indicates success?",
      "options": ["200", "404", "500"],
      "correctAnswer": 0,
      "explanation": "200 OK indicates successful request"
    }
  ]
}
```
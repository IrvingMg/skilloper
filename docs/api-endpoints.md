# API Endpoints Reference

Base URL: `http://localhost:8080/api/v1`

## Endpoints

### Questionnaires

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/health` | Health check |
| `GET` | `/questionnaires/summaries` | Get paginated questionnaire summaries |
| `POST` | `/questionnaires/import` | Import questionnaire from file (JSON/CSV) |
| `GET` | `/questionnaires/{id}` | Get specific questionnaire (shuffled questions) |
| `PUT` | `/questionnaires/{id}` | Update questionnaire |
| `DELETE` | `/questionnaires/{id}` | Delete questionnaire |

### Quiz Attempts

| Method | Endpoint | Description |
|--------|----------|-------------|
| `POST` | `/attempts/start` | Start a quiz attempt (creates in_progress record) |
| `POST` | `/attempts/{id}/complete` | Complete a quiz attempt (server validates answers) |
| `GET` | `/attempts` | Get paginated attempt history for a device |
| `GET` | `/attempts/{id}` | Get specific attempt with answers |

### Questions (Practice Mode)

| Method | Endpoint | Description |
|--------|----------|-------------|
| `POST` | `/questions/{id}/validate` | Validate answer for immediate feedback |

### Pagination Parameters

Both `/questionnaires/summaries` and `/attempts` support pagination and filtering:

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `limit` | int | 20 | Items per page (max 100) |
| `offset` | int | 0 | Items to skip |
| `search` | string | "" | Search in title (case-insensitive) |
| `type` | string | "" | Filter by type: `practice` or `exam` |

**Note:** `/attempts` also requires `device_id` parameter.

#### Attempt Tracking Behavior

The app handles attempts differently based on quiz mode:

| Mode | On Quiz Start | On Quiz Exit | On Quiz Complete |
|------|---------------|--------------|------------------|
| **Practice** | No attempt created | Nothing recorded | Start + Complete attempt |
| **Exam** | Attempt created (in_progress) | Stays as "abandoned" | Complete attempt |

- **Practice mode**: Attempts are only recorded when completed. Users can exit freely without affecting their history.
- **Exam mode**: Attempts are tracked from the start. Abandoning an exam leaves an "in_progress" record visible in history.

## Usage Examples

### Health Check
```bash
curl http://localhost:8080/api/v1/health
```

### Get Questionnaire Summaries
```bash
# Basic request (returns first 20 items)
curl http://localhost:8080/api/v1/questionnaires/summaries

# With pagination and filters
curl "http://localhost:8080/api/v1/questionnaires/summaries?limit=10&offset=0&search=javascript&type=practice"
```

Response:
```json
{
  "data": [
    {
      "id": 1,
      "title": "JavaScript Basics",
      "description": "Learn JS fundamentals",
      "type": "practice",
      "max_options": 4,
      "question_count": 10,
      "created_at": "2025-01-15T10:00:00Z",
      "updated_at": "2025-01-15T10:00:00Z"
    }
  ],
  "pagination": {
    "limit": 10,
    "offset": 0,
    "total_count": 25,
    "has_more": true
  }
}
```

### Import Questionnaire from File
```bash
curl -X POST http://localhost:8080/api/v1/questionnaires/import \
  -F "file=@questionnaire.json"
```

See [questionnaire-schema.md](questionnaire-schema.md) for the complete JSON schema.

### Get Specific Questionnaire
```bash
curl http://localhost:8080/api/v1/questionnaires/1
```

### Update Questionnaire
```bash
curl -X PUT http://localhost:8080/api/v1/questionnaires/1 \
  -H "Content-Type: application/json" \
  -d @updated-questionnaire.json
```

### Delete Questionnaire
```bash
curl -X DELETE http://localhost:8080/api/v1/questionnaires/1
```

### Start Quiz Attempt
```bash
curl -X POST http://localhost:8080/api/v1/attempts/start \
  -H "Content-Type: application/json" \
  -d '{
    "device_id": "550e8400-e29b-41d4-a716-446655440000",
    "questionnaire_id": 1,
    "questionnaire_title": "JavaScript Basics",
    "questionnaire_type": "practice",
    "total_count": 10
  }'
```

Response:
```json
{
  "id": 1,
  "device_id": "550e8400-e29b-41d4-a716-446655440000",
  "questionnaire_id": 1,
  "questionnaire_title": "JavaScript Basics",
  "questionnaire_type": "practice",
  "attempt_number": 1,
  "status": "in_progress",
  "score": 0,
  "correct_count": 0,
  "total_count": 10,
  "created_at": "2025-01-15T10:30:00Z",
  "completed_at": null,
  "answers": []
}
```

### Complete Quiz Attempt

The client sends only user answers. The server validates answers and calculates the score.

```bash
curl -X POST http://localhost:8080/api/v1/attempts/1/complete \
  -H "Content-Type: application/json" \
  -d '{
    "answers": [
      {
        "question_id": 1,
        "user_answer": 2
      },
      {
        "question_id": 2,
        "user_answers": [0, 2]
      }
    ]
  }'
```

**Request Fields:**
- `answers[].question_id` - Question ID
- `answers[].user_answer` - Selected option index (single choice)
- `answers[].user_answers` - Selected option indices (multiple choice)

**Note:** Duplicate `question_id` entries are ignored (only the first submission per question is counted).

**Response:** Server returns the attempt with validated results including correct answers, score, and per-question feedback.

### Get Attempt History
```bash
# Basic request (returns first 20 items)
curl "http://localhost:8080/api/v1/attempts?device_id=550e8400-e29b-41d4-a716-446655440000"

# With pagination and filters
curl "http://localhost:8080/api/v1/attempts?device_id=550e8400-e29b-41d4-a716-446655440000&limit=10&offset=0&search=javascript&type=exam"
```

Response:
```json
{
  "data": [
    {
      "id": 1,
      "device_id": "550e8400-e29b-41d4-a716-446655440000",
      "questionnaire_id": 1,
      "questionnaire_title": "JavaScript Basics",
      "questionnaire_type": "practice",
      "attempt_number": 1,
      "status": "completed",
      "score": 80,
      "correct_count": 8,
      "total_count": 10,
      "created_at": "2025-01-15T10:30:00Z",
      "completed_at": "2025-01-15T10:45:00Z"
    }
  ],
  "pagination": {
    "limit": 10,
    "offset": 0,
    "total_count": 5,
    "has_more": false
  }
}
```

### Get Specific Attempt
```bash
curl http://localhost:8080/api/v1/attempts/1
```

### Validate Answer (Practice Mode)

Used in practice mode for immediate feedback after answering a question.

```bash
# Single choice
curl -X POST http://localhost:8080/api/v1/questions/1/validate \
  -H "Content-Type: application/json" \
  -d '{"user_answer": 2}'

# Multiple choice
curl -X POST http://localhost:8080/api/v1/questions/1/validate \
  -H "Content-Type: application/json" \
  -d '{"user_answers": [0, 2]}'
```

Response:
```json
{
  "is_correct": false,
  "correct_answer": 1
}
```

Or for multiple choice:
```json
{
  "is_correct": false,
  "correct_answers": [0, 2, 3]
}
```

## Security: Server-Side Answer Validation

**Important:** Correct answers are never sent to the client during quizzes.

- `GET /questionnaires/{id}` returns questions **without** `correct_answer` or `correct_answers` fields
- The client collects user answers only
- `POST /attempts/{id}/complete` receives user answers, the **server** validates and calculates the score
- `POST /questions/{id}/validate` is only used in practice mode for immediate feedback

This prevents submitting fake scores.

## Error Responses

The API returns structured error responses:

```json
{
  "error": "Detailed error message",
  "code": "ERROR_CODE"
}
```

### Common Error Codes

| Code | Description |
|------|-------------|
| `QUESTIONNAIRE_NOT_FOUND` | Questionnaire with given ID doesn't exist |
| `INVALID_JSON_FORMAT` | Malformed JSON in request body |
| `FILE_REQUIRED` | No file provided for import |
| `QUESTION_TEXT_REQUIRED` | Question text is missing |
| `INVALID_CORRECT_ANSWER` | Answer index is out of range |
| `ATTEMPT_NOT_FOUND` | Attempt with given ID doesn't exist |
| `DEVICE_ID_REQUIRED` | Device ID query parameter is missing |
| `ATTEMPT_ALREADY_COMPLETED` | Cannot complete an already completed attempt |
| `INVALID_ATTEMPT_DATA` | Invalid data in attempt request |
| `INVALID_PAGINATION_PARAMS` | Invalid pagination parameters (e.g., invalid type filter) |
| `QUESTION_NOT_FOUND` | Question with given ID doesn't exist |
| `INVALID_QUESTION_ID` | Invalid question ID format |
| `INVALID_ANSWER_DATA` | Missing user_answer or user_answers in request |

### HTTP Status Codes

- `200` - Success
- `400` - Bad Request (validation errors)
- `404` - Not Found
- `422` - Unprocessable Entity (file validation)
- `500` - Internal Server Error
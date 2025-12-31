# API Endpoints Reference

Base URL: `http://localhost:8080/api/v1`

## Endpoints

### Questionnaires

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/health` | Health check |
| `GET` | `/questionnaires/summaries` | Get questionnaire summaries (optimized for home page) |
| `POST` | `/questionnaires/import` | Import questionnaire from file (JSON/CSV) |
| `GET` | `/questionnaires/{id}` | Get specific questionnaire (shuffled questions) |
| `PUT` | `/questionnaires/{id}` | Update questionnaire |
| `DELETE` | `/questionnaires/{id}` | Delete questionnaire |

### Quiz Attempts

| Method | Endpoint | Description |
|--------|----------|-------------|
| `POST` | `/attempts/start` | Start a quiz attempt (creates in_progress record) |
| `POST` | `/attempts/{id}/complete` | Complete a quiz attempt with results |
| `GET` | `/attempts?device_id={id}` | Get attempt history for a device |
| `GET` | `/attempts/{id}` | Get specific attempt with answers |

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
curl http://localhost:8080/api/v1/questionnaires/summaries
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
```bash
curl -X POST http://localhost:8080/api/v1/attempts/1/complete \
  -H "Content-Type: application/json" \
  -d '{
    "score": 80,
    "correct_count": 8,
    "total_count": 10,
    "answers": [
      {
        "question_id": 1,
        "question_text": "What is typeof null?",
        "question_type": "single_choice",
        "user_answer": 2,
        "correct_answer": 2,
        "options": ["null", "undefined", "object", "boolean"],
        "is_correct": true
      }
    ]
  }'
```

### Get Attempt History
```bash
curl "http://localhost:8080/api/v1/attempts?device_id=550e8400-e29b-41d4-a716-446655440000"
```

Response:
```json
[
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
]
```

### Get Specific Attempt
```bash
curl http://localhost:8080/api/v1/attempts/1
```

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

### HTTP Status Codes

- `200` - Success
- `400` - Bad Request (validation errors)
- `404` - Not Found
- `422` - Unprocessable Entity (file validation)
- `500` - Internal Server Error
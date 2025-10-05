# API Endpoints Reference

Base URL: `http://localhost:8080/api/v1`

## Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/health` | Health check |
| `GET` | `/questionnaires/summaries` | Get questionnaire summaries (optimized for home page) |
| `POST` | `/questionnaires/import` | Import questionnaire from file (JSON/CSV) |
| `GET` | `/questionnaires/{id}` | Get specific questionnaire (shuffled questions) |
| `PUT` | `/questionnaires/{id}` | Update questionnaire |
| `DELETE` | `/questionnaires/{id}` | Delete questionnaire |

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

### HTTP Status Codes

- `200` - Success
- `400` - Bad Request (validation errors)
- `404` - Not Found
- `422` - Unprocessable Entity (file validation)
- `500` - Internal Server Error
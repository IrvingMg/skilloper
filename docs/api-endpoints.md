# API Endpoints Reference

Base URL: `http://localhost:8080/api/v1`

## Authentication

The API uses JWT (JSON Web Token) authentication. After logging in, include the token in the `Authorization` header for protected endpoints.

```
Authorization: Bearer <token>
```

### Public Endpoints
- `GET /health` - Health check
- `POST /users` - Register
- `POST /sessions` - Login

### Protected Endpoints (require authentication)
All other endpoints require a valid JWT token:
- `GET /users/me` - Get current user
- `DELETE /sessions` - Logout
- All quiz endpoints (`/quizzes/*`)
- All attempt endpoints (`/attempts/*`)
- Answer validation (`POST /answers`)

## Endpoints

### System

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/health` | Health check |

### Authentication

| Method | Endpoint | Description |
|--------|----------|-------------|
| `POST` | `/users` | Create user account (register) |
| `GET` | `/users/me` | Get current user info (protected) |
| `POST` | `/sessions` | Create session (login) |
| `DELETE` | `/sessions` | Destroy session (logout, protected) |

### Quizzes

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/quizzes/summaries` | Get paginated quiz summaries |
| `POST` | `/quizzes` | Create quiz (JSON body) or import from file (multipart/form-data) |
| `GET` | `/quizzes/{id}` | Get specific quiz with alternative text selection |
| `PUT` | `/quizzes/{id}` | Update quiz |
| `DELETE` | `/quizzes/{id}` | Delete quiz |

### Quiz Attempts (Protected)

| Method | Endpoint | Description |
|--------|----------|-------------|
| `POST` | `/attempts` | Create a quiz attempt (in_progress status) |
| `PATCH` | `/attempts/{id}` | Update attempt status (complete or abandon) |
| `GET` | `/attempts` | Get paginated attempt history for current user |
| `GET` | `/attempts/{id}` | Get specific attempt with answers |

### Answers (Practice Mode)

| Method | Endpoint | Description |
|--------|----------|-------------|
| `POST` | `/answers` | Submit answer for immediate feedback |

### Pagination Parameters

Both `/quizzes/summaries` and `/attempts` support pagination, filtering, and sorting:

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `limit` | int | 20 | Items per page (max 100) |
| `offset` | int | 0 | Items to skip |
| `search` | string | "" | Search in title (case-insensitive) |
| `type` | string | "" | Filter by type: `practice` or `exam` |
| `sort` | string | `date_desc` | Sort order (see below) |

#### Sort Options

**For quizzes (`/quizzes/summaries`):**
| Value | Description |
|-------|-------------|
| `date_desc` | Newest first (default) |
| `date_asc` | Oldest first |
| `title_asc` | Title A-Z |
| `title_desc` | Title Z-A |

**For attempts (`/attempts`):**
| Value | Description |
|-------|-------------|
| `date_desc` | Newest first (default) |
| `date_asc` | Oldest first |
| `score_desc` | Highest score first |
| `score_asc` | Lowest score first |
| `title_asc` | Quiz title A-Z |
| `title_desc` | Quiz title Z-A |

#### Attempt Tracking Behavior

The app handles attempts differently based on quiz mode:

| Mode | On Quiz Start | On Quiz Exit | On Quiz Complete |
|------|---------------|--------------|------------------|
| **Practice** | No attempt created | Nothing recorded | Start + Complete attempt |
| **Exam** | Attempt created (in_progress) | Calls `PATCH /attempts/:id` with no answers (marks as abandoned) | Complete attempt |

- **Practice mode**: Attempts are only recorded when completed. Users can exit freely without affecting their history.
- **Exam mode**: Attempts are tracked from the start. Abandoning an exam marks it with `abandoned` status.

## Usage Examples

### Health Check
```bash
curl http://localhost:8080/api/v1/health
```

### Register User

**Validation Requirements:**
- Username: 6-30 characters, alphanumeric and underscore only (stored lowercase)
- Password: 8-72 characters, must contain at least one uppercase letter, one lowercase letter, and one digit

```bash
curl -X POST http://localhost:8080/api/v1/users \
  -H "Content-Type: application/json" \
  -d '{"username": "john_doe", "password": "MyPassword123"}'
```

Response (includes token for immediate login):
```json
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "user": {
    "id": 1,
    "username": "john_doe",
    "created_at": "2025-01-15T10:00:00Z"
  }
}
```

### Login
```bash
curl -X POST http://localhost:8080/api/v1/sessions \
  -H "Content-Type: application/json" \
  -d '{"username": "john_doe", "password": "mypassword123"}'
```

Response:
```json
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "user": {
    "id": 1,
    "username": "john_doe",
    "created_at": "2025-01-15T10:00:00Z"
  }
}
```

### Get Current User
```bash
curl http://localhost:8080/api/v1/users/me \
  -H "Authorization: Bearer <token>"
```

### Logout
```bash
curl -X DELETE http://localhost:8080/api/v1/sessions \
  -H "Authorization: Bearer <token>"
```

### Get Quiz Summaries
```bash
# Basic request (returns first 20 items)
curl http://localhost:8080/api/v1/quizzes/summaries \
  -H "Authorization: Bearer <token>"

# With pagination and filters
curl "http://localhost:8080/api/v1/quizzes/summaries?limit=10&offset=0&search=javascript&type=practice" \
  -H "Authorization: Bearer <token>"
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

### Import Quiz from File

Supports JSON and CSV formats. Maximum file size: **10 MB**.

Use `POST /quizzes` with `multipart/form-data` Content-Type:

```bash
# JSON file (simple or internal format)
curl -X POST http://localhost:8080/api/v1/quizzes \
  -H "Authorization: Bearer <token>" \
  -F "file=@quiz.json"

# CSV file with metadata via query params
curl -X POST "http://localhost:8080/api/v1/quizzes?title=My%20Quiz&type=practice" \
  -H "Authorization: Bearer <token>" \
  -F "file=@questions.csv"
```

See [quiz-schema.md](quiz-schema.md) for all supported formats and limits.

### Get Specific Quiz
```bash
curl http://localhost:8080/api/v1/quizzes/1 \
  -H "Authorization: Bearer <token>"
```

### Update Quiz
```bash
curl -X PUT http://localhost:8080/api/v1/quizzes/1 \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <token>" \
  -d @updated-quiz.json
```

### Delete Quiz
```bash
curl -X DELETE http://localhost:8080/api/v1/quizzes/1 \
  -H "Authorization: Bearer <token>"
```

### Create Quiz Attempt
```bash
curl -X POST http://localhost:8080/api/v1/attempts \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <token>" \
  -d '{"quiz_id": 1}'
```

Response:
```json
{
  "id": 1,
  "user_id": 1,
  "quiz_id": 1,
  "quiz_title": "JavaScript Basics",
  "quiz_type": "practice",
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

### Update Quiz Attempt

Use `PATCH /attempts/{id}` to complete or abandon an attempt.

**Complete with answers:**
```bash
curl -X PATCH http://localhost:8080/api/v1/attempts/1 \
  -H "Content-Type: application/json" \
  -d '{
    "status": "completed",
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

**Abandon (no answers):**
```bash
curl -X PATCH http://localhost:8080/api/v1/attempts/1 \
  -H "Content-Type: application/json" \
  -d '{"status": "completed"}'
```

**Note:** When no answers are provided, the server marks the attempt as `abandoned` (not `completed`). The response will show `"status": "abandoned"`.

**Request Fields:**
- `status` - Must be "completed"
- `answers[].question_id` - Question ID
- `answers[].user_answer` - Selected option index (single choice)
- `answers[].user_answers` - Selected option indices (multiple choice)

**Note:** Duplicate `question_id` entries are ignored (only the first submission per question is counted).

**Response:** Server returns the attempt with validated results including correct answers, score, and per-question feedback.

### Get Attempt History
```bash
# Basic request (returns first 20 items)
curl http://localhost:8080/api/v1/attempts \
  -H "Authorization: Bearer <token>"

# With pagination and filters
curl "http://localhost:8080/api/v1/attempts?limit=10&offset=0&search=javascript&type=exam" \
  -H "Authorization: Bearer <token>"
```

Response:
```json
{
  "data": [
    {
      "id": 1,
      "user_id": 1,
      "quiz_id": 1,
      "quiz_title": "JavaScript Basics",
      "quiz_type": "practice",
      "attempt_number": 1,
      "status": "completed",
      "score": 80,
      "correct_count": 8,
      "total_count": 10,
      "created_at": "2025-01-15T10:30:00Z",
      "completed_at": "2025-01-15T10:45:00Z"
    },
    {
      "id": 2,
      "user_id": 1,
      "quiz_id": 1,
      "quiz_title": "JavaScript Basics",
      "quiz_type": "exam",
      "attempt_number": 2,
      "status": "abandoned",
      "score": 0,
      "correct_count": 0,
      "total_count": 10,
      "created_at": "2025-01-15T11:00:00Z",
      "completed_at": "2025-01-15T11:05:00Z"
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

**Attempt Status Values:**
- `in_progress` - Quiz started but not yet completed
- `completed` - Quiz finished with all answers submitted
- `abandoned` - Quiz was exited early, no answers recorded

### Get Specific Attempt
```bash
curl http://localhost:8080/api/v1/attempts/1 \
  -H "Authorization: Bearer <token>"
```

### Submit Answer (Practice Mode)

Used in practice mode for immediate feedback after answering a question.

```bash
# Single choice
curl -X POST http://localhost:8080/api/v1/answers \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <token>" \
  -d '{"question_id": 1, "user_answer": 2}'

# Multiple choice
curl -X POST http://localhost:8080/api/v1/answers \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <token>" \
  -d '{"question_id": 1, "user_answers": [0, 2]}'
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

- `GET /quizzes/{id}` returns questions **without** `correct_answer` or `correct_answers` fields
- The client collects user answers only
- `PATCH /attempts/{id}` receives user answers, the **server** validates and calculates the score
- `POST /answers` is only used in practice mode for immediate feedback

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
| `QUIZ_NOT_FOUND` | Quiz with given ID doesn't exist |
| `INVALID_JSON_FORMAT` | Malformed JSON in request body |
| `FILE_REQUIRED` | No file provided for import |
| `QUESTION_TEXT_REQUIRED` | Question text is missing |
| `INVALID_CORRECT_ANSWER` | Answer index is out of range |
| `ATTEMPT_NOT_FOUND` | Attempt with given ID doesn't exist |
| `INVALID_ATTEMPT_DATA` | Invalid data in attempt request (e.g., already completed) |
| `INVALID_PAGINATION_PARAMS` | Invalid pagination parameters (e.g., invalid type filter) |
| `QUESTION_NOT_FOUND` | Question with given ID doesn't exist |
| `INVALID_QUESTION_ID` | Invalid question ID format |
| `INVALID_ANSWER_DATA` | Missing user_answer or user_answers in request |
| `INVALID_CREDENTIALS` | Login failed (wrong username or password) |
| `USERNAME_TAKEN` | Username already exists |
| `UNAUTHORIZED` | Missing or invalid authentication token |
| `INVALID_TOKEN` | Token is invalid, expired, or has been revoked |
| `WEAK_PASSWORD` | Password doesn't meet complexity requirements |
| `ACCOUNT_LOCKED` | Account temporarily locked due to too many failed login attempts |

### HTTP Status Codes

- `200` - Success
- `201` - Created (user registration, session creation)
- `400` - Bad Request (validation errors)
- `401` - Unauthorized (missing/invalid token, invalid credentials)
- `404` - Not Found
- `409` - Conflict (username taken)
- `422` - Unprocessable Entity (file validation)
- `429` - Too Many Requests (account locked)
- `500` - Internal Server Error
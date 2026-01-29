# API Endpoints Reference

Base URL: `http://localhost:8080/api/v1`

## Authentication

The API uses JWT (JSON Web Token) authentication with refresh tokens for session management.

**Token Strategy:**
- **Access Token**: Short-lived JWT (1 hour default), included in `Authorization` header
- **Refresh Token**: Long-lived opaque token (7 days default), used to obtain new access tokens

```
Authorization: Bearer <access_token>
```

**Automatic Token Refresh:**
When an access token expires, use the refresh token to obtain a new token pair without re-authenticating. The client should automatically retry failed 401 requests after refreshing.

### Public Endpoints
- `GET /health` - Health check
- `POST /users` - Register
- `POST /sessions` - Login
- `POST /sessions/refresh` - Refresh tokens

### Protected Endpoints (require authentication)
All other endpoints require a valid JWT token:
- `GET /users/me` - Get current user
- `PUT /users/me/password` - Update password
- `POST /users/me/history-clearance` - Clear quiz history
- `POST /users/me/deletion` - Delete account
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
| `PUT` | `/users/me/password` | Update password (protected) |
| `POST` | `/users/me/history-clearance` | Clear quiz history (protected) |
| `POST` | `/users/me/deletion` | Delete account (protected) |
| `POST` | `/sessions` | Create session (login) |
| `POST` | `/sessions/refresh` | Refresh access token |
| `DELETE` | `/sessions` | Destroy session (logout, protected) |

### Quizzes

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/quizzes/summaries` | Get paginated quiz summaries |
| `POST` | `/quizzes` | Create quiz (JSON body) or import from file (multipart/form-data) |
| `GET` | `/quizzes/{id}` | Get specific quiz with alternative text selection |
| `PUT` | `/quizzes/{id}` | Update quiz |
| `DELETE` | `/quizzes/{id}` | Delete quiz |
| `POST` | `/quizzes/bulk-delete` | Bulk delete multiple quizzes |

**Ownership:** Quizzes are private to the user who created them. Users can only list, view, update, and delete their own quizzes. Admins can access all quizzes. Attempting to access another user's quiz returns `403 Forbidden` with code `NOT_QUIZ_OWNER`.

### Collections (Protected)

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/collections` | Get paginated collection summaries |
| `GET` | `/collections/flat` | Get all collections as flat list with full paths |
| `GET` | `/collections/{id}` | Get specific collection |
| `POST` | `/collections` | Create collection |
| `PUT` | `/collections/{id}` | Update collection |
| `DELETE` | `/collections/{id}` | Delete collection (quizzes become uncategorized) |
| `PATCH` | `/quizzes/{id}/collection` | Set or remove quiz's collection |
| `POST` | `/quizzes/bulk-collection` | Bulk update collection for multiple quizzes |

**Ownership:** Collections are private to the user who created them. Admins can access all collections.

**Subcollections:** Collections support hierarchical organization via `parent_id`. A collection can have a parent collection, creating a tree structure.

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

The endpoints `/quizzes/summaries`, `/attempts`, and `/collections` support pagination, filtering, and sorting:

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

**For collections (`/collections`):**
| Value | Description |
|-------|-------------|
| `date_desc` | Newest first (default) |
| `date_asc` | Oldest first |
| `name_asc` | Name A-Z |
| `name_desc` | Name Z-A |

**Additional collection parameters:**
| Parameter | Type | Description |
|-----------|------|-------------|
| `parent_id` | int | Filter by parent collection (omit to get root-level collections) |

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

Response (includes tokens for immediate login):
```json
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "refresh_token": "dGhpcyBpcyBhIHJlZnJlc2ggdG9rZW4...",
  "expires_in": 3600,
  "refresh_token_expires_in": 604800,
  "user": {
    "id": 1,
    "username": "john_doe",
    "created_at": "2025-01-15T10:00:00Z"
  }
}
```

**Response Fields:**
- `token` - JWT access token for API authentication
- `refresh_token` - Opaque token for obtaining new access tokens
- `expires_in` - Access token validity in seconds (3600 = 1 hour)
- `refresh_token_expires_in` - Refresh token validity in seconds (604800 = 7 days default)

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
  "refresh_token": "dGhpcyBpcyBhIHJlZnJlc2ggdG9rZW4...",
  "expires_in": 3600,
  "refresh_token_expires_in": 604800,
  "user": {
    "id": 1,
    "username": "john_doe",
    "created_at": "2025-01-15T10:00:00Z"
  }
}
```

### Refresh Tokens

Use this endpoint to obtain a new access token when the current one expires. This allows users to stay logged in without re-entering credentials.

```bash
curl -X POST http://localhost:8080/api/v1/sessions/refresh \
  -H "Content-Type: application/json" \
  -d '{"refresh_token": "dGhpcyBpcyBhIHJlZnJlc2ggdG9rZW4..."}'
```

Response:
```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "refresh_token": "bmV3IHJlZnJlc2ggdG9rZW4...",
  "expires_in": 3600,
  "refresh_token_expires_in": 604800
}
```

**Token Rotation:** Each refresh returns a new refresh token. The previous refresh token is immediately revoked. This limits the window of opportunity if a token is compromised.

**Security:** If a revoked refresh token is used (indicating potential theft), all tokens in that session family are revoked, requiring re-authentication.

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

### Update Password
```bash
curl -X PUT http://localhost:8080/api/v1/users/me/password \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <token>" \
  -d '{"current_password": "OldPassword123", "new_password": "NewPassword456"}'
```

Response (includes new token since password change invalidates old tokens):
```json
{
  "message": "Password updated successfully",
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

### Clear Quiz History
```bash
curl -X POST http://localhost:8080/api/v1/users/me/history-clearance \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <token>" \
  -d '{"password": "MyPassword123"}'
```

Response:
```json
{
  "message": "Quiz history cleared successfully",
  "deleted_count": 15
}
```

### Delete Account
```bash
curl -X POST http://localhost:8080/api/v1/users/me/deletion \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <token>" \
  -d '{"password": "MyPassword123"}'
```

Response:
```json
{
  "message": "Account deleted successfully"
}
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
      "collection_id": 2,
      "collection_name": "Web Development",
      "collection_ancestors": [
        {"id": 1, "name": "Programming"}
      ],
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

**Quiz summary fields:**
- `collection_id`: ID of the quiz's collection (null if uncategorized)
- `collection_name`: Name of the quiz's collection
- `collection_ancestors`: Parent collections from root to parent (for nested collections)

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

### Get Collections
```bash
# Basic request
curl http://localhost:8080/api/v1/collections \
  -H "Authorization: Bearer <token>"

# With filters
curl "http://localhost:8080/api/v1/collections?search=go&sort=name_asc" \
  -H "Authorization: Bearer <token>"

# Get subcollections of a specific collection
curl "http://localhost:8080/api/v1/collections?parent_id=1" \
  -H "Authorization: Bearer <token>"
```

Response:
```json
{
  "data": [
    {
      "id": 1,
      "parent_id": null,
      "name": "Go Fundamentals",
      "quiz_count": 5,
      "total_quiz_count": 12,
      "child_count": 2,
      "ancestors": [],
      "created_at": "2025-01-15T10:00:00Z",
      "updated_at": "2025-01-15T10:00:00Z"
    }
  ],
  "pagination": {
    "limit": 20,
    "offset": 0,
    "total_count": 1,
    "has_more": false
  }
}
```

**Collection fields:**
- `quiz_count`: Number of quizzes directly in this collection
- `total_quiz_count`: Total quizzes including all descendants
- `child_count`: Number of direct subcollections
- `ancestors`: Breadcrumb chain from root to parent (for nested collections)

### Create Collection
```bash
curl -X POST http://localhost:8080/api/v1/collections \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <token>" \
  -d '{"name": "Go Fundamentals"}'

# With parent (subcollection)
curl -X POST http://localhost:8080/api/v1/collections \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <token>" \
  -d '{"name": "Concurrency", "parent_id": 1}'
```

### Update Collection
```bash
curl -X PUT http://localhost:8080/api/v1/collections/1 \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <token>" \
  -d '{"name": "Go Basics"}'
```

### Delete Collection
```bash
curl -X DELETE http://localhost:8080/api/v1/collections/1 \
  -H "Authorization: Bearer <token>"
```

**Note:** Deleting a collection does not delete its quizzes. Quizzes become uncategorized (`collection_id` set to null).

### Set Quiz Collection
```bash
# Move quiz to a collection
curl -X PATCH http://localhost:8080/api/v1/quizzes/1/collection \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <token>" \
  -d '{"collection_id": 1}'

# Remove quiz from collection
curl -X PATCH http://localhost:8080/api/v1/quizzes/1/collection \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <token>" \
  -d '{"collection_id": null}'
```

### Bulk Update Quiz Collection
```bash
# Move multiple quizzes to a collection
curl -X POST http://localhost:8080/api/v1/quizzes/bulk-collection \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <token>" \
  -d '{"quiz_ids": [1, 2, 3], "collection_id": 1}'

# Remove multiple quizzes from collection
curl -X POST http://localhost:8080/api/v1/quizzes/bulk-collection \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <token>" \
  -d '{"quiz_ids": [1, 2, 3], "collection_id": null}'
```

### Bulk Delete Quizzes
```bash
curl -X POST http://localhost:8080/api/v1/quizzes/bulk-delete \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <token>" \
  -d '{"quiz_ids": [1, 2, 3]}'
```

### Get Flat Collections
```bash
curl http://localhost:8080/api/v1/collections/flat \
  -H "Authorization: Bearer <token>"
```

Response:
```json
[
  {
    "id": 1,
    "name": "Programming",
    "full_path": "Programming"
  },
  {
    "id": 2,
    "name": "Go",
    "full_path": "Programming > Go"
  },
  {
    "id": 3,
    "name": "Concurrency",
    "full_path": "Programming > Go > Concurrency"
  }
]
```

**Note:** The flat list includes all collections with their full hierarchical path, useful for search/selection UIs.

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
| `NOT_QUIZ_OWNER` | User doesn't own this quiz (403) |
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
| `COLLECTION_NOT_FOUND` | Collection with given ID doesn't exist |
| `NOT_COLLECTION_OWNER` | User doesn't own this collection (403) |
| `COLLECTION_NAME_REQUIRED` | Collection name is missing |
| `PARENT_COLLECTION_NOT_FOUND` | Parent collection doesn't exist |
| `CIRCULAR_COLLECTION_REFERENCE` | Operation would create a circular parent chain |
| `UNAUTHORIZED` | Missing or invalid authentication token |
| `INVALID_TOKEN` | Token is invalid, expired, or has been revoked |
| `WEAK_PASSWORD` | Password doesn't meet complexity requirements |
| `ACCOUNT_LOCKED` | Account temporarily locked due to too many failed login attempts |
| `RATE_LIMIT_EXCEEDED` | Too many requests, try again later |

### HTTP Status Codes

- `200` - Success
- `201` - Created (user registration, session creation)
- `400` - Bad Request (validation errors)
- `401` - Unauthorized (missing/invalid token, invalid credentials)
- `403` - Forbidden (not quiz owner)
- `404` - Not Found
- `409` - Conflict (username taken)
- `422` - Unprocessable Entity (file validation)
- `429` - Too Many Requests (rate limit exceeded or account locked)
- `500` - Internal Server Error

## Rate Limiting

When rate limiting is enabled, the API enforces request limits to prevent abuse.

### Rate Limits (Default)

| Endpoint | Limit | Key |
|----------|-------|-----|
| `POST /sessions` (login) | 5/min | IP + username |
| `POST /users` (register) | 3/min | IP + username |
| All authenticated endpoints | 120/min | User ID |

IP-only limits (3x the above values) also apply to login/register to prevent username rotation attacks.

### Rate Limit Headers

All responses include rate limit information:

```
X-RateLimit-Limit: 5
X-RateLimit-Remaining: 3
X-RateLimit-Reset: 1704825600
```

### Rate Limit Exceeded Response (429)

```json
{
  "error": "Too many requests. Please try again later.",
  "code": "RATE_LIMIT_EXCEEDED"
}
```

Headers on 429 responses:
```
Retry-After: 45
```

The `Retry-After` header indicates seconds until the limit resets.
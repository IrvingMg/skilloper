# Quiz Import Formats

This document defines the supported formats for importing quizzes into Skilloper.

## Supported Formats

| Format | Extension | Indexing | Best For |
|--------|-----------|----------|----------|
| **Simple JSON** | `.json` | 1-based | Users, manual creation |
| **CSV** | `.csv` | 1-based | Spreadsheets, bulk import |
| **Internal JSON** | `.json` | 0-based | API consumers, programmatic use |

---

## Simple JSON Format (Recommended for Users)

The user-friendly format with 1-based indexing and simplified `answer` field.

```json
{
  "title": "My Quiz",
  "description": "Optional description",
  "type": "practice",
  "max_options": 4,
  "questions": [
    {
      "question": "What is 2+2?",
      "options": ["1", "2", "3", "4"],
      "answer": ["4"],
      "explanation": "Basic math",
      "code": "console.log(2+2);",
      "language": "javascript",
      "alternative_questions": ["Calculate 2+2"],
      "extra_options": ["5", "6"],
      "option_variants": [[], [], [], ["four", "IV"]]
    }
  ]
}
```

### Simple JSON Fields

| Field | Required | Description |
|-------|----------|-------------|
| `title` | Yes | Quiz title |
| `questions` | Yes | Array of questions |
| `question` | Yes | Question text |
| `options` | Yes | Answer options (2-8) |
| `answer` | Yes | **1-based** indices as strings: `["4"]` single, `["1","2","4"]` multiple |
| `description` | No | Quiz description |
| `type` | No | `"practice"` (default) or `"exam"` |
| `max_options` | No | 2-8, limits options per question |
| `question_type` | No | `"single_choice"` or `"multiple_choice"`. If omitted, auto-detected from answer count |
| `explanation` | No | Answer explanation |
| `code` | No | Code snippet |
| `language` | No | Syntax highlighting (e.g., "javascript") |
| `alternative_questions` | No | Alternative phrasings |
| `extra_options` | No | Additional distractor options |
| `option_variants` | No | Text variants per option: `option_variants[i]` = variants for `options[i]` |

---

## CSV Format

Spreadsheet-friendly format with one question per row.

```csv
question,option1,option2,option3,option4,answer,explanation,code,language,alt_question1,alt_option1
"What is 2+2?","1","2","3","4",4,"Basic math","console.log(2+2);","javascript","Calculate 2+2","5"
"Select primes","2","3","4","5","1,2,4","2,3,5 are prime","","","","6"
```

### CSV Columns

| Column | Required | Description |
|--------|----------|-------------|
| `question` | Yes | Question text |
| `option1`-`option8` | 2+ required | Answer options |
| `answer` | Yes | **1-based**: `4` single, `"1,2,4"` multiple |
| `explanation` | No | Answer explanation |
| `code` | No | Code snippet |
| `language` | No | Syntax highlighting language |
| `alt_question1`, `alt_question2`, ... | No | Alternative questions |
| `alt_option1`, `alt_option2`, ... | No | Alternative options |

### CSV Metadata

**In the app:** When importing a CSV file, you'll be prompted to enter the quiz title, description, type, and max options.

**Via API:** Quiz-level metadata is passed via query parameters:

```bash
curl -X POST "http://localhost:8080/api/v1/quizzes?title=My%20Quiz&type=practice&max_options=4" \
  -F "file=@questions.csv"
```

| Parameter | Default | Description |
|-----------|---------|-------------|
| `title` | Filename | Quiz title |
| `description` | Empty | Quiz description |
| `type` | `practice` | `"practice"` or `"exam"` |
| `max_options` | 4 | Maximum options per question |

---

## Internal JSON Format (Advanced)

The internal API format with 0-based indexing. Used by the UI wizard and API consumers.

**Important:** Include `"format": "internal"` at the root level to use 0-based indexing. Without this field, the parser assumes Simple JSON format with 1-based indexing.

### Schema

```json
{
  "format": "internal",
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
      "extra_options": ["string", "string"] (optional),
      "correct_answers": [0] (required, 0-based indices - single element for single_choice, multiple for multiple_choice),
      "option_variants": [["variant1"], [], ["variant1", "variant2"]] (optional),
      "explanation": "string (optional)"
    }
  ]
}
```

## Field Reference

### Quiz Level

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `title` | string | Yes | Name of the quiz |
| `description` | string | No | Brief description of the quiz content |
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
| `extra_options` | array | No | Additional distractor options for shuffling variety |
| `correct_answers` | array | Yes | **Required.** Array of 0-based indices. Single element `[2]` for single_choice, multiple elements `[0, 1, 3]` for multiple_choice |
| `option_variants` | 2D array | No | Text variants per option: `option_variants[i]` contains alternative texts for `options[i]` |
| `explanation` | string | No | Explanation shown after answering, describing why the answer is correct |

## Limits

| Limit | Value | Description |
|-------|-------|-------------|
| Max file size | 10 MB | Maximum upload size for import |
| Max questions | 500 | Maximum questions per quiz |
| Max options | 8 | Maximum answer options per question |
| Min options | 2 | Minimum answer options per question |
| Max title length | 255 | Maximum characters for title |
| Max description length | 1000 | Maximum characters for description |
| Max alternative questions | 10 | Maximum alternative phrasings per question |
| Max extra options | 20 | Maximum additional distractor options per question |

---

## Key Behaviors

- **Answer Indexing**: Simple JSON and CSV use 1-based indices (user-friendly). Internal JSON uses 0-based indices (programmatic). The server converts automatically on import
- **Hybrid Shuffling for Variety**:
  - **Backend**: Randomly selects from `alternative_questions` and `option_variants` for text variety
  - **Frontend**: Shuffles option display order while mapping selections back to original indices
  - **Result**: Each quiz attempt feels different while maintaining correct server-side validation
- **Question Order**: Questions maintain their original order
- **Validation**: API returns detailed errors if limits are exceeded or required fields are missing
- **Duplicate Protection**: Server ignores duplicate question submissions in attempt completion

## Security Note

**Import vs API Response:**
- When **importing** a quiz, `correctAnswer`/`correct_answers` are **required** and stored securely
- When **fetching** a quiz via `GET /quizzes/{id}`, these fields are **hidden** from the response
- Answer validation happens **server-side** to prevent submitting fake scores

See [api-endpoints.md](api-endpoints.md) for details on the secure answer validation flow.

## Examples

### Single Choice Question with Code
```json
{
  "format": "internal",
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
      "extra_options": ["string", "number"],
      "correct_answers": [2],
      "option_variants": [[], [], ["object type", "the object string"], []],
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
  "extra_options": ["undefined", "symbol", "bigint"],
  "correct_answers": [0, 1, 2, 3],
  "option_variants": [["text"], ["numeric", "integer"], ["bool"], ["Object"]],
  "explanation": "All listed options are valid JavaScript primitive and non-primitive types"
}
```

### Question with Option Limits
```json
{
  "format": "internal",
  "title": "Quick Quiz",
  "description": "Short questions with limited options",
  "type": "practice",
  "max_options": 3,
  "questions": [
    {
      "question": "Which HTTP status code indicates success?",
      "options": ["200", "404", "500"],
      "correct_answers": [0],
      "explanation": "200 OK indicates successful request"
    }
  ]
}
```
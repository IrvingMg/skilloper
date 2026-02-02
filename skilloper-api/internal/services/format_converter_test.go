package services

import (
	"strings"
	"testing"

	"github.com/irvingmg/skilloper/skilloper-api/internal/models"
)

func TestJSONParser_CanParse(t *testing.T) {
	p := NewJSONParser()

	tests := []struct {
		name     string
		data     []byte
		filename string
		want     bool
	}{
		{"json file with object", []byte(`{"title": "test"}`), "quiz.json", true},
		{"json file with array", []byte(`[{"question": "test"}]`), "quiz.json", true},
		{"json with whitespace", []byte(`  {"title": "test"}  `), "quiz.json", true},
		{"csv file", []byte(`question,answer`), "quiz.csv", false},
		{"txt file", []byte(`{"title": "test"}`), "quiz.txt", false},
		{"no extension", []byte(`{"title": "test"}`), "quiz", false},
		{"uppercase JSON", []byte(`{"title": "test"}`), "quiz.JSON", true},
		{"empty json file", []byte(``), "quiz.json", false},
		{"whitespace only", []byte(`   `), "quiz.json", false},
		{"invalid json content", []byte(`not json`), "quiz.json", false},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := p.CanParse(tt.data, tt.filename); got != tt.want {
				t.Errorf("CanParse() = %v, want %v", got, tt.want)
			}
		})
	}
}

func TestJSONParser_Parse_SimpleFormat(t *testing.T) {
	p := NewJSONParser()

	jsonData := `{
		"title": "Test Quiz",
		"description": "A test",
		"type": "exam",
		"questions": [
			{
				"question": "What is 2+2?",
				"options": ["3", "4", "5"],
				"answer": ["2"]
			}
		]
	}`

	result, err := p.Parse([]byte(jsonData), ParserMetadata{})
	if err != nil {
		t.Fatalf("Parse() error = %v", err)
	}

	if result.Title != "Test Quiz" {
		t.Errorf("Title = %q, want %q", result.Title, "Test Quiz")
	}
	if result.Description != "A test" {
		t.Errorf("Description = %q, want %q", result.Description, "A test")
	}
	if result.Type != "exam" {
		t.Errorf("Type = %q, want %q", result.Type, "exam")
	}
	if len(result.Questions) != 1 {
		t.Fatalf("Questions count = %d, want 1", len(result.Questions))
	}

	q := result.Questions[0]
	if q.QuestionType != "single_choice" {
		t.Errorf("QuestionType = %q, want %q", q.QuestionType, "single_choice")
	}
	if len(q.CorrectAnswers) != 1 || q.CorrectAnswers[0] != 1 { // 0-indexed from "2"
		t.Errorf("CorrectAnswers = %v, want [1]", q.CorrectAnswers)
	}
}

func TestJSONParser_Parse_InternalFormat(t *testing.T) {
	p := NewJSONParser()

	jsonData := `{
		"format": "internal",
		"title": "Internal Quiz",
		"type": "practice",
		"questions": [
			{
				"question": "Test question",
				"question_type": "single_choice",
				"options": ["A", "B", "C"],
				"correct_answer": 0
			}
		]
	}`

	result, err := p.Parse([]byte(jsonData), ParserMetadata{})
	if err != nil {
		t.Fatalf("Parse() error = %v", err)
	}

	if result.Title != "Internal Quiz" {
		t.Errorf("Title = %q, want %q", result.Title, "Internal Quiz")
	}
	// Internal format should be passed through directly
	if len(result.Questions) != 1 {
		t.Fatalf("Questions count = %d, want 1", len(result.Questions))
	}
}

func TestJSONParser_Parse_MultipleChoice(t *testing.T) {
	p := NewJSONParser()

	jsonData := `{
		"title": "Multi Quiz",
		"questions": [
			{
				"question": "Select all primes",
				"options": ["2", "3", "4", "5"],
				"answer": ["1", "2", "4"]
			}
		]
	}`

	result, err := p.Parse([]byte(jsonData), ParserMetadata{})
	if err != nil {
		t.Fatalf("Parse() error = %v", err)
	}

	q := result.Questions[0]
	if q.QuestionType != "multiple_choice" {
		t.Errorf("QuestionType = %q, want %q", q.QuestionType, "multiple_choice")
	}
	expected := []int{0, 1, 3} // 0-indexed from "1", "2", "4"
	if len(q.CorrectAnswers) != len(expected) {
		t.Fatalf("CorrectAnswers count = %d, want %d", len(q.CorrectAnswers), len(expected))
	}
	for i, v := range expected {
		if q.CorrectAnswers[i] != v {
			t.Errorf("CorrectAnswers[%d] = %d, want %d", i, q.CorrectAnswers[i], v)
		}
	}
}

func TestJSONParser_Parse_MissingTitle(t *testing.T) {
	p := NewJSONParser()

	jsonData := `{
		"questions": [
			{
				"question": "Test",
				"options": ["A", "B"],
				"answer": ["1"]
			}
		]
	}`

	_, err := p.Parse([]byte(jsonData), ParserMetadata{})
	if err == nil {
		t.Error("Parse() should fail with missing title")
	}
	if !strings.Contains(err.Error(), "title") {
		t.Errorf("Error should mention 'title', got: %v", err)
	}
}

func TestJSONParser_Parse_NoQuestions(t *testing.T) {
	p := NewJSONParser()

	jsonData := `{
		"title": "Empty Quiz",
		"questions": []
	}`

	_, err := p.Parse([]byte(jsonData), ParserMetadata{})
	if err == nil {
		t.Error("Parse() should fail with no questions")
	}
}

func TestJSONParser_Parse_InvalidType(t *testing.T) {
	p := NewJSONParser()

	jsonData := `{
		"title": "Test",
		"type": "invalid",
		"questions": [
			{
				"question": "Test",
				"options": ["A", "B"],
				"answer": ["1"]
			}
		]
	}`

	_, err := p.Parse([]byte(jsonData), ParserMetadata{})
	if err == nil {
		t.Error("Parse() should fail with invalid type")
	}
}

func TestJSONParser_Parse_DefaultType(t *testing.T) {
	p := NewJSONParser()

	jsonData := `{
		"title": "Test",
		"questions": [
			{
				"question": "Test",
				"options": ["A", "B"],
				"answer": ["1"]
			}
		]
	}`

	result, err := p.Parse([]byte(jsonData), ParserMetadata{})
	if err != nil {
		t.Fatalf("Parse() error = %v", err)
	}
	if result.Type != "practice" {
		t.Errorf("Type = %q, want %q (default)", result.Type, "practice")
	}
}

func TestJSONParser_Parse_TooFewOptions(t *testing.T) {
	p := NewJSONParser()

	jsonData := `{
		"title": "Test",
		"questions": [
			{
				"question": "Test",
				"options": ["A"],
				"answer": ["1"]
			}
		]
	}`

	_, err := p.Parse([]byte(jsonData), ParserMetadata{})
	if err == nil {
		t.Error("Parse() should fail with < 2 options")
	}
}

func TestJSONParser_Parse_InvalidJSON(t *testing.T) {
	p := NewJSONParser()

	_, err := p.Parse([]byte(`{invalid json`), ParserMetadata{})
	if err == nil {
		t.Error("Parse() should fail with invalid JSON")
	}
}

func TestJSONParser_Parse_WithOptionalFields(t *testing.T) {
	p := NewJSONParser()

	jsonData := `{
		"title": "Code Quiz",
		"questions": [
			{
				"question": "What does this print?",
				"options": ["Hello", "World"],
				"answer": ["1"],
				"explanation": "Prints Hello",
				"code": "print('Hello')",
				"language": "python",
				"alternative_questions": ["Alt question 1"],
				"alternative_options": ["Alt option 1"]
			}
		]
	}`

	result, err := p.Parse([]byte(jsonData), ParserMetadata{})
	if err != nil {
		t.Fatalf("Parse() error = %v", err)
	}

	q := result.Questions[0]
	if q.Explanation != "Prints Hello" {
		t.Errorf("Explanation = %q, want %q", q.Explanation, "Prints Hello")
	}
	if q.Code != "print('Hello')" {
		t.Errorf("Code = %q, want %q", q.Code, "print('Hello')")
	}
	if q.Language != "python" {
		t.Errorf("Language = %q, want %q", q.Language, "python")
	}
}

// Test SimplifiedQuestion.ParseAnswer directly since it has meaningful logic
func TestSimplifiedQuestion_ParseAnswer(t *testing.T) {
	tests := []struct {
		name        string
		question    models.SimplifiedQuestion
		wantType    string
		wantAnswers []int
		wantErr     bool
	}{
		{
			name: "single answer",
			question: models.SimplifiedQuestion{
				Options: []string{"A", "B", "C"},
				Answer:  []string{"2"},
			},
			wantType:    "single_choice",
			wantAnswers: []int{1},
			wantErr:     false,
		},
		{
			name: "multiple answers",
			question: models.SimplifiedQuestion{
				Options: []string{"A", "B", "C", "D"},
				Answer:  []string{"1", "3"},
			},
			wantType:    "multiple_choice",
			wantAnswers: []int{0, 2},
			wantErr:     false,
		},
		{
			name: "explicit single choice with one answer",
			question: models.SimplifiedQuestion{
				QuestionType: "single_choice",
				Options:      []string{"A", "B"},
				Answer:       []string{"1"},
			},
			wantType:    "single_choice",
			wantAnswers: []int{0},
			wantErr:     false,
		},
		{
			name: "explicit multiple choice",
			question: models.SimplifiedQuestion{
				QuestionType: "multiple_choice",
				Options:      []string{"A", "B", "C"},
				Answer:       []string{"1", "2"},
			},
			wantType:    "multiple_choice",
			wantAnswers: []int{0, 1},
			wantErr:     false,
		},
		{
			name: "empty answer",
			question: models.SimplifiedQuestion{
				Options: []string{"A", "B"},
				Answer:  []string{},
			},
			wantErr: true,
		},
		{
			name: "answer out of range",
			question: models.SimplifiedQuestion{
				Options: []string{"A", "B"},
				Answer:  []string{"5"},
			},
			wantErr: true,
		},
		{
			name: "answer zero (invalid)",
			question: models.SimplifiedQuestion{
				Options: []string{"A", "B"},
				Answer:  []string{"0"},
			},
			wantErr: true,
		},
		{
			name: "duplicate answers",
			question: models.SimplifiedQuestion{
				Options: []string{"A", "B", "C"},
				Answer:  []string{"1", "1"},
			},
			wantErr: true,
		},
		{
			name: "not a number",
			question: models.SimplifiedQuestion{
				Options: []string{"A", "B"},
				Answer:  []string{"abc"},
			},
			wantErr: true,
		},
		{
			name: "single_choice type but multiple answers",
			question: models.SimplifiedQuestion{
				QuestionType: "single_choice",
				Options:      []string{"A", "B", "C"},
				Answer:       []string{"1", "2"},
			},
			wantErr: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result, err := tt.question.ParseAnswer()
			if (err != nil) != tt.wantErr {
				t.Errorf("ParseAnswer() error = %v, wantErr %v", err, tt.wantErr)
				return
			}
			if tt.wantErr {
				return
			}

			if result.QuestionType != tt.wantType {
				t.Errorf("QuestionType = %q, want %q", result.QuestionType, tt.wantType)
			}

			if len(result.CorrectAnswers) != len(tt.wantAnswers) {
				t.Errorf("CorrectAnswers = %v, want %v", result.CorrectAnswers, tt.wantAnswers)
				return
			}
			for i, v := range tt.wantAnswers {
				if result.CorrectAnswers[i] != v {
					t.Errorf("CorrectAnswers[%d] = %d, want %d", i, result.CorrectAnswers[i], v)
				}
			}
		})
	}
}

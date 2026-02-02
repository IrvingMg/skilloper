package services

import (
	"strings"
	"testing"
)

func TestSanitizeCSVValue(t *testing.T) {
	tests := []struct {
		name  string
		input string
		want  string
	}{
		{"normal value", "hello", "hello"},
		{"with spaces", "  hello  ", "hello"},
		{"empty", "", ""},
		{"starts with equals", "=SUM(A1)", "'=SUM(A1)"},
		{"starts with plus", "+1234", "'+1234"},
		{"starts with minus", "-1234", "'-1234"},
		{"starts with at", "@import", "'@import"},
		{"equals in middle is ok", "a=b", "a=b"},
		// Note: tab/carriage return at start get trimmed away by TrimSpace
		{"tab trimmed", "\tvalue", "value"},
		{"carriage return trimmed", "\rvalue", "value"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := sanitizeCSVValue(tt.input); got != tt.want {
				t.Errorf("sanitizeCSVValue(%q) = %q, want %q", tt.input, got, tt.want)
			}
		})
	}
}

func TestCSVParser_ParseSingleAnswer(t *testing.T) {
	p := NewCSVParser()

	tests := []struct {
		name       string
		answer     string
		numOptions int
		want       int
		wantErr    bool
	}{
		{"valid answer 1", "1", 4, 0, false},
		{"valid answer 2", "2", 4, 1, false},
		{"valid answer 4", "4", 4, 3, false},
		{"out of range high", "5", 4, 0, true},
		{"out of range zero", "0", 4, 0, true},
		{"negative", "-1", 4, 0, true},
		{"not a number", "abc", 4, 0, true},
		{"empty", "", 4, 0, true},
		{"with spaces", " 2 ", 4, 0, true}, // spaces not trimmed in this function
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got, err := p.parseSingleAnswer(tt.answer, tt.numOptions)
			if (err != nil) != tt.wantErr {
				t.Errorf("parseSingleAnswer() error = %v, wantErr %v", err, tt.wantErr)
				return
			}
			if !tt.wantErr && got != tt.want {
				t.Errorf("parseSingleAnswer() = %d, want %d", got, tt.want)
			}
		})
	}
}

func TestCSVParser_ParseMultipleAnswers(t *testing.T) {
	p := NewCSVParser()

	tests := []struct {
		name       string
		answer     string
		numOptions int
		want       []int
		wantErr    bool
	}{
		{"single answer", "1", 4, []int{0}, false},
		{"two answers", "1,2", 4, []int{0, 1}, false},
		{"three answers", "1,2,4", 4, []int{0, 1, 3}, false},
		{"with spaces", "1, 2, 3", 4, []int{0, 1, 2}, false},
		{"out of range", "1,5", 4, nil, true},
		{"duplicate", "1,1", 4, nil, true},
		{"not a number", "1,abc", 4, nil, true},
		{"empty string", "", 4, nil, true},
		{"only commas", ",,", 4, nil, true},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got, err := p.parseMultipleAnswers(tt.answer, tt.numOptions)
			if (err != nil) != tt.wantErr {
				t.Errorf("parseMultipleAnswers() error = %v, wantErr %v", err, tt.wantErr)
				return
			}
			if !tt.wantErr {
				if len(got) != len(tt.want) {
					t.Errorf("parseMultipleAnswers() = %v, want %v", got, tt.want)
					return
				}
				for i := range got {
					if got[i] != tt.want[i] {
						t.Errorf("parseMultipleAnswers() = %v, want %v", got, tt.want)
						return
					}
				}
			}
		})
	}
}

func TestCSVParser_IsEmptyRow(t *testing.T) {
	p := NewCSVParser()

	tests := []struct {
		name   string
		record []string
		want   bool
	}{
		{"all empty", []string{"", "", ""}, true},
		{"all whitespace", []string{"  ", "\t", "  "}, true},
		{"has value", []string{"", "value", ""}, false},
		{"single empty", []string{""}, true},
		{"empty slice", []string{}, true},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := p.isEmptyRow(tt.record); got != tt.want {
				t.Errorf("isEmptyRow() = %v, want %v", got, tt.want)
			}
		})
	}
}

func TestCSVParser_ParseHeader(t *testing.T) {
	p := NewCSVParser()

	tests := []struct {
		name    string
		header  []string
		wantErr bool
		errMsg  string
	}{
		{
			name:    "valid basic header",
			header:  []string{"question", "option1", "option2", "answer"},
			wantErr: false,
		},
		{
			name:    "valid with optional columns",
			header:  []string{"question", "option1", "option2", "option3", "answer", "explanation", "code", "language"},
			wantErr: false,
		},
		{
			name:    "missing question column",
			header:  []string{"option1", "option2", "answer"},
			wantErr: true,
			errMsg:  "question",
		},
		{
			name:    "missing answer column",
			header:  []string{"question", "option1", "option2"},
			wantErr: true,
			errMsg:  "answer",
		},
		{
			name:    "only one option",
			header:  []string{"question", "option1", "answer"},
			wantErr: true,
			errMsg:  "at least 2 option",
		},
		{
			name:    "case insensitive",
			header:  []string{"QUESTION", "Option1", "OPTION2", "Answer"},
			wantErr: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			_, err := p.parseHeader(tt.header)
			if (err != nil) != tt.wantErr {
				t.Errorf("parseHeader() error = %v, wantErr %v", err, tt.wantErr)
				return
			}
			if tt.wantErr && tt.errMsg != "" && !strings.Contains(err.Error(), tt.errMsg) {
				t.Errorf("parseHeader() error = %v, should contain %q", err, tt.errMsg)
			}
		})
	}
}

func TestCSVParser_ParseCSV_ValidSingleChoice(t *testing.T) {
	p := NewCSVParser()
	csv := `question,option1,option2,option3,answer,explanation
What is 2+2?,3,4,5,2,Basic math
What is 3+3?,5,6,7,2,More math`

	meta := CSVMetadata{Title: "Test Quiz", Type: "practice"}
	result, err := p.ParseCSV(strings.NewReader(csv), meta)
	if err != nil {
		t.Fatalf("ParseCSV() error = %v", err)
	}

	if result.Title != "Test Quiz" {
		t.Errorf("Title = %q, want %q", result.Title, "Test Quiz")
	}
	if len(result.Questions) != 2 {
		t.Fatalf("Questions count = %d, want 2", len(result.Questions))
	}

	q := result.Questions[0]
	if q.Question != "What is 2+2?" {
		t.Errorf("Question = %q, want %q", q.Question, "What is 2+2?")
	}
	if len(q.CorrectAnswers) != 1 || q.CorrectAnswers[0] != 1 { // 0-indexed, so answer "2" becomes 1
		t.Errorf("CorrectAnswers = %v, want [1]", q.CorrectAnswers)
	}
	if q.QuestionType != "single_choice" {
		t.Errorf("QuestionType = %q, want %q", q.QuestionType, "single_choice")
	}
	if q.Explanation != "Basic math" {
		t.Errorf("Explanation = %q, want %q", q.Explanation, "Basic math")
	}
}

func TestCSVParser_ParseCSV_ValidMultipleChoice(t *testing.T) {
	p := NewCSVParser()
	csv := `question,option1,option2,option3,option4,answer
Select primes,2,3,4,5,"1,2,4"`

	meta := CSVMetadata{Title: "Test Quiz", Type: "exam"}
	result, err := p.ParseCSV(strings.NewReader(csv), meta)
	if err != nil {
		t.Fatalf("ParseCSV() error = %v", err)
	}

	if len(result.Questions) != 1 {
		t.Fatalf("Questions count = %d, want 1", len(result.Questions))
	}

	q := result.Questions[0]
	if q.QuestionType != "multiple_choice" {
		t.Errorf("QuestionType = %q, want %q", q.QuestionType, "multiple_choice")
	}
	if len(q.CorrectAnswers) != 3 {
		t.Errorf("CorrectAnswers count = %d, want 3", len(q.CorrectAnswers))
	}
	// Should be 0, 1, 3 (0-indexed from 1, 2, 4)
	expected := []int{0, 1, 3}
	for i, v := range expected {
		if q.CorrectAnswers[i] != v {
			t.Errorf("CorrectAnswers[%d] = %d, want %d", i, q.CorrectAnswers[i], v)
		}
	}
}

func TestCSVParser_ParseCSV_EmptyRows(t *testing.T) {
	p := NewCSVParser()
	csv := `question,option1,option2,answer
What is 1+1?,1,2,2

What is 2+2?,3,4,2
   ,   ,   ,
What is 3+3?,5,6,2`

	meta := CSVMetadata{Title: "Test Quiz"}
	result, err := p.ParseCSV(strings.NewReader(csv), meta)
	if err != nil {
		t.Fatalf("ParseCSV() error = %v", err)
	}

	if len(result.Questions) != 3 {
		t.Errorf("Questions count = %d, want 3 (empty rows should be skipped)", len(result.Questions))
	}
}

func TestCSVParser_ParseCSV_MissingTitle(t *testing.T) {
	p := NewCSVParser()
	csv := `question,option1,option2,answer
What is 1+1?,1,2,2`

	meta := CSVMetadata{Title: ""} // Missing title
	_, err := p.ParseCSV(strings.NewReader(csv), meta)
	if err == nil {
		t.Error("ParseCSV() should fail with missing title")
	}
}

func TestCSVParser_ParseCSV_InvalidAnswer(t *testing.T) {
	p := NewCSVParser()
	csv := `question,option1,option2,answer
What is 1+1?,1,2,5`

	meta := CSVMetadata{Title: "Test Quiz"}
	_, err := p.ParseCSV(strings.NewReader(csv), meta)
	if err == nil {
		t.Error("ParseCSV() should fail with out-of-range answer")
	}
}

func TestCSVParser_ParseCSV_NoQuestions(t *testing.T) {
	p := NewCSVParser()
	csv := `question,option1,option2,answer`

	meta := CSVMetadata{Title: "Test Quiz"}
	_, err := p.ParseCSV(strings.NewReader(csv), meta)
	if err == nil {
		t.Error("ParseCSV() should fail with no questions")
	}
}

func TestCSVParser_ParseCSV_WithCode(t *testing.T) {
	p := NewCSVParser()
	// Code with quotes needs proper CSV escaping (double the quotes inside quoted field)
	csv := `question,option1,option2,answer,code,language
What does this print?,Hello,World,1,"print(""Hello"")",python`

	meta := CSVMetadata{Title: "Test Quiz"}
	result, err := p.ParseCSV(strings.NewReader(csv), meta)
	if err != nil {
		t.Fatalf("ParseCSV() error = %v", err)
	}

	q := result.Questions[0]
	if q.Code != `print("Hello")` {
		t.Errorf("Code = %q, want %q", q.Code, `print("Hello")`)
	}
	if q.Language != "python" {
		t.Errorf("Language = %q, want %q", q.Language, "python")
	}
}

func TestCSVParser_ParseCSV_InvalidType(t *testing.T) {
	p := NewCSVParser()
	csv := `question,option1,option2,answer
What is 1+1?,1,2,2`

	meta := CSVMetadata{Title: "Test Quiz", Type: "invalid"}
	_, err := p.ParseCSV(strings.NewReader(csv), meta)
	if err == nil {
		t.Error("ParseCSV() should fail with invalid type")
	}
}

func TestCSVParser_ParseCSV_DefaultType(t *testing.T) {
	p := NewCSVParser()
	csv := `question,option1,option2,answer
What is 1+1?,1,2,2`

	meta := CSVMetadata{Title: "Test Quiz", Type: ""} // Empty type
	result, err := p.ParseCSV(strings.NewReader(csv), meta)
	if err != nil {
		t.Fatalf("ParseCSV() error = %v", err)
	}
	if result.Type != "practice" {
		t.Errorf("Type = %q, want %q (default)", result.Type, "practice")
	}
}

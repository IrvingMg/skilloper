package models

import (
	"fmt"
	"strconv"
)

// Format constants for JSON parsing
const (
	FormatSimple   = "simple"   // User-friendly: 1-based indexing, answer as string array (default)
	FormatInternal = "internal" // API format: 0-based indexing, correctAnswer/correct_answers
)

// SimplifiedQuestionnaire represents the user-friendly JSON format
// with 1-based indexing and simplified answer field
type SimplifiedQuestionnaire struct {
	Format      string               `json:"format,omitempty"` // "simple" (default) or "internal"
	Title       string               `json:"title"`
	Description string               `json:"description,omitempty"`
	Type        string               `json:"type,omitempty"` // "practice" or "exam", defaults to "practice"
	MaxOptions  int                  `json:"max_options,omitempty"`
	Questions   []SimplifiedQuestion `json:"questions"`
}

// IsInternalFormat returns true if this questionnaire uses internal API format
func (sq *SimplifiedQuestionnaire) IsInternalFormat() bool {
	return sq.Format == FormatInternal
}

// SimplifiedQuestion uses Answer as array of strings for simplicity
// Accepts: ["4"] for single choice, ["1", "2", "4"] for multiple choice
// All values are 1-based indices
type SimplifiedQuestion struct {
	Question             string   `json:"question"`
	AlternativeQuestions []string `json:"alternative_questions,omitempty"` // Alternative question phrasings
	Options              []string `json:"options"`
	AlternativeOptions   []string `json:"alternative_options,omitempty"` // Additional options for variety
	Answer               []string `json:"answer"`                        // Array of 1-based indices as strings
	AlternativeAnswers   []string `json:"alternative_answers,omitempty"` // Alternative correct answer texts
	Explanation          string   `json:"explanation,omitempty"`
	Code                 string   `json:"code,omitempty"`
	Language             string   `json:"language,omitempty"`
}

// ParsedAnswer holds the normalized answer data after parsing
type ParsedAnswer struct {
	QuestionType   string // "single_choice" or "multiple_choice"
	CorrectAnswer  int    // 0-based index for single choice
	CorrectAnswers []int  // 0-based indices for multiple choice
}

// ParseAnswer converts the Answer string array to normalized form
// Input: 1-based index(es) as strings from user
// Output: 0-based index(es) for internal API
func (sq *SimplifiedQuestion) ParseAnswer() (*ParsedAnswer, error) {
	if len(sq.Answer) == 0 {
		return nil, fmt.Errorf("answer is required")
	}

	// Parse all answers to 0-based indices
	answers := make([]int, 0, len(sq.Answer))
	seen := make(map[int]bool)

	for i, s := range sq.Answer {
		idx, err := strconv.Atoi(s)
		if err != nil {
			return nil, fmt.Errorf("answer[%d] '%s' is not a valid number", i, s)
		}
		if idx < 1 {
			return nil, fmt.Errorf("answer[%d] must be >= 1 (1-based indexing), got %d", i, idx)
		}
		if idx > len(sq.Options) {
			return nil, fmt.Errorf("answer[%d] value %d exceeds number of options (%d)", i, idx, len(sq.Options))
		}

		zeroBasedIdx := idx - 1
		if seen[zeroBasedIdx] {
			return nil, fmt.Errorf("duplicate answer value: %s", s)
		}
		seen[zeroBasedIdx] = true
		answers = append(answers, zeroBasedIdx)
	}

	if len(answers) == 0 {
		return nil, fmt.Errorf("at least one valid answer is required")
	}

	// Determine question type based on number of answers
	if len(answers) == 1 {
		return &ParsedAnswer{
			QuestionType:  QuestionTypeSingleChoice,
			CorrectAnswer: answers[0],
		}, nil
	}

	return &ParsedAnswer{
		QuestionType:   QuestionTypeMultipleChoice,
		CorrectAnswers: answers,
	}, nil
}

package models

import (
	"testing"
)

func TestQuestion_ApplyAlternativeAnswers(t *testing.T) {
	tests := []struct {
		name           string
		question       Question
		options        []string
		correctAnswers []int
		wantModified   bool // whether the correct answer option should potentially change
	}{
		{
			name: "single choice with alternatives",
			question: Question{
				QuestionType:       QuestionTypeSingleChoice,
				CorrectAnswer:      1,
				AlternativeAnswers: `["Alt Answer 1", "Alt Answer 2"]`,
			},
			options:        []string{"Option A", "Option B", "Option C"},
			correctAnswers: nil,
			wantModified:   true,
		},
		{
			name: "multiple choice with alternatives",
			question: Question{
				QuestionType:       QuestionTypeMultipleChoice,
				CorrectAnswers:     `[0, 2]`,
				AlternativeAnswers: `["Alt Answer"]`,
			},
			options:        []string{"Option A", "Option B", "Option C"},
			correctAnswers: []int{0, 2},
			wantModified:   true,
		},
		{
			name: "no alternatives - returns unchanged",
			question: Question{
				QuestionType:       QuestionTypeSingleChoice,
				CorrectAnswer:      0,
				AlternativeAnswers: "",
			},
			options:        []string{"Option A", "Option B"},
			correctAnswers: nil,
			wantModified:   false,
		},
		{
			name: "empty options - returns empty",
			question: Question{
				QuestionType:       QuestionTypeSingleChoice,
				CorrectAnswer:      0,
				AlternativeAnswers: `["Alt"]`,
			},
			options:        []string{},
			correctAnswers: nil,
			wantModified:   false,
		},
		{
			name: "invalid alternatives JSON - returns unchanged",
			question: Question{
				QuestionType:       QuestionTypeSingleChoice,
				CorrectAnswer:      0,
				AlternativeAnswers: `invalid json`,
			},
			options:        []string{"Option A", "Option B"},
			correctAnswers: nil,
			wantModified:   false,
		},
		{
			name: "correct answer out of bounds - returns unchanged",
			question: Question{
				QuestionType:       QuestionTypeSingleChoice,
				CorrectAnswer:      10,
				AlternativeAnswers: `["Alt"]`,
			},
			options:        []string{"Option A", "Option B"},
			correctAnswers: nil,
			wantModified:   false,
		},
		{
			name: "multiple choice with empty correct answers - returns unchanged",
			question: Question{
				QuestionType:       QuestionTypeMultipleChoice,
				CorrectAnswers:     `[]`,
				AlternativeAnswers: `["Alt"]`,
			},
			options:        []string{"Option A", "Option B"},
			correctAnswers: []int{},
			wantModified:   false,
		},
		{
			name: "negative correct answer - returns unchanged",
			question: Question{
				QuestionType:       QuestionTypeSingleChoice,
				CorrectAnswer:      -1,
				AlternativeAnswers: `["Alt"]`,
			},
			options:        []string{"Option A", "Option B"},
			correctAnswers: nil,
			wantModified:   false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Make a copy of options to compare
			originalOptions := make([]string, len(tt.options))
			copy(originalOptions, tt.options)

			result := tt.question.ApplyAlternativeAnswers(tt.options, tt.correctAnswers)

			// Check that result is returned
			if result == nil && len(tt.options) > 0 {
				t.Error("ApplyAlternativeAnswers returned nil for non-nil input")
			}

			// Check length is preserved
			if len(result) != len(originalOptions) {
				t.Errorf("Length changed: got %d, want %d", len(result), len(originalOptions))
			}

			if !tt.wantModified {
				// Verify options unchanged
				for i, opt := range result {
					if opt != originalOptions[i] {
						t.Errorf("Option %d was modified when it shouldn't be: got %q, want %q", i, opt, originalOptions[i])
					}
				}
			}
		})
	}
}

func TestQuestion_ApplyAlternativeAnswers_ValidAlternativeSelected(t *testing.T) {
	question := Question{
		QuestionType:       QuestionTypeSingleChoice,
		CorrectAnswer:      1,
		AlternativeAnswers: `["Alt B1", "Alt B2"]`,
	}
	options := []string{"Option A", "Option B", "Option C"}
	validValues := map[string]bool{
		"Option B": true,
		"Alt B1":   true,
		"Alt B2":   true,
	}

	// Run multiple times to verify random selection works
	for i := 0; i < 20; i++ {
		optionsCopy := make([]string, len(options))
		copy(optionsCopy, options)

		result := question.ApplyAlternativeAnswers(optionsCopy, nil)

		// Check that the modified option is one of the valid values
		if !validValues[result[1]] {
			t.Errorf("Invalid value selected: got %q", result[1])
		}

		// Check that other options are unchanged
		if result[0] != "Option A" {
			t.Errorf("Option 0 should not change: got %q", result[0])
		}
		if result[2] != "Option C" {
			t.Errorf("Option 2 should not change: got %q", result[2])
		}
	}
}

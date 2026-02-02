package models

import (
	"testing"
)

func TestQuestion_ApplyOptionVariants(t *testing.T) {
	tests := []struct {
		name         string
		question     Question
		options      []string
		wantModified bool // whether any option should potentially change
	}{
		{
			name: "single option with variants",
			question: Question{
				QuestionType:   QuestionTypeSingleChoice,
				CorrectAnswers: `[1]`,
				OptionVariants: `[[], ["Alt B1", "Alt B2"], []]`,
			},
			options:      []string{"Option A", "Option B", "Option C"},
			wantModified: true,
		},
		{
			name: "multiple options with variants",
			question: Question{
				QuestionType:   QuestionTypeMultipleChoice,
				CorrectAnswers: `[0, 2]`,
				OptionVariants: `[["Alt A"], [], ["Alt C1", "Alt C2"]]`,
			},
			options:      []string{"Option A", "Option B", "Option C"},
			wantModified: true,
		},
		{
			name: "no variants - returns unchanged",
			question: Question{
				QuestionType:   QuestionTypeSingleChoice,
				CorrectAnswers: `[0]`,
				OptionVariants: "",
			},
			options:      []string{"Option A", "Option B"},
			wantModified: false,
		},
		{
			name: "empty options - returns empty",
			question: Question{
				QuestionType:   QuestionTypeSingleChoice,
				CorrectAnswers: `[0]`,
				OptionVariants: `[["Alt"]]`,
			},
			options:      []string{},
			wantModified: false,
		},
		{
			name: "invalid variants JSON - returns unchanged",
			question: Question{
				QuestionType:   QuestionTypeSingleChoice,
				CorrectAnswers: `[0]`,
				OptionVariants: `invalid json`,
			},
			options:      []string{"Option A", "Option B"},
			wantModified: false,
		},
		{
			name: "empty variants array - returns unchanged",
			question: Question{
				QuestionType:   QuestionTypeSingleChoice,
				CorrectAnswers: `[0]`,
				OptionVariants: `[]`,
			},
			options:      []string{"Option A", "Option B"},
			wantModified: false,
		},
		{
			name: "all empty variant arrays - returns unchanged",
			question: Question{
				QuestionType:   QuestionTypeSingleChoice,
				CorrectAnswers: `[0]`,
				OptionVariants: `[[], []]`,
			},
			options:      []string{"Option A", "Option B"},
			wantModified: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Make a copy of options to compare
			originalOptions := make([]string, len(tt.options))
			copy(originalOptions, tt.options)

			result := tt.question.ApplyOptionVariants(tt.options)

			// Check that result is returned
			if result == nil && len(tt.options) > 0 {
				t.Error("ApplyOptionVariants returned nil for non-nil input")
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

func TestQuestion_ApplyOptionVariants_ValidVariantSelected(t *testing.T) {
	question := Question{
		QuestionType:   QuestionTypeSingleChoice,
		CorrectAnswers: `[1]`,
		OptionVariants: `[[], ["Alt B1", "Alt B2"], []]`,
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

		result := question.ApplyOptionVariants(optionsCopy)

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

func TestQuestion_ApplyOptionVariants_MultipleOptions(t *testing.T) {
	question := Question{
		QuestionType:   QuestionTypeMultipleChoice,
		CorrectAnswers: `[0, 2]`,
		OptionVariants: `[["Alt A"], [], ["Alt C"]]`,
	}
	options := []string{"Option A", "Option B", "Option C"}
	validA := map[string]bool{"Option A": true, "Alt A": true}
	validC := map[string]bool{"Option C": true, "Alt C": true}

	// Run multiple times to verify random selection works
	for i := 0; i < 20; i++ {
		optionsCopy := make([]string, len(options))
		copy(optionsCopy, options)

		result := question.ApplyOptionVariants(optionsCopy)

		// Check that options 0 and 2 have valid values
		if !validA[result[0]] {
			t.Errorf("Invalid value selected for option 0: got %q", result[0])
		}
		if !validC[result[2]] {
			t.Errorf("Invalid value selected for option 2: got %q", result[2])
		}

		// Check that option 1 is unchanged
		if result[1] != "Option B" {
			t.Errorf("Option 1 should not change: got %q", result[1])
		}
	}
}

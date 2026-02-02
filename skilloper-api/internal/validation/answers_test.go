package validation

import "testing"

func TestValidateMultipleChoice(t *testing.T) {
	tests := []struct {
		name           string
		userAnswers    []int
		correctAnswers []int
		want           bool
	}{
		{
			name:           "exact match",
			userAnswers:    []int{0, 1},
			correctAnswers: []int{0, 1},
			want:           true,
		},
		{
			name:           "different order is valid",
			userAnswers:    []int{1, 0},
			correctAnswers: []int{0, 1},
			want:           true,
		},
		{
			name:           "three answers different order",
			userAnswers:    []int{2, 0, 1},
			correctAnswers: []int{0, 1, 2},
			want:           true,
		},
		{
			name:           "partial match is invalid",
			userAnswers:    []int{0},
			correctAnswers: []int{0, 1},
			want:           false,
		},
		{
			name:           "extra selection is invalid",
			userAnswers:    []int{0, 1, 2},
			correctAnswers: []int{0, 1},
			want:           false,
		},
		{
			name:           "wrong answers",
			userAnswers:    []int{2, 3},
			correctAnswers: []int{0, 1},
			want:           false,
		},
		{
			name:           "empty user answers",
			userAnswers:    []int{},
			correctAnswers: []int{0},
			want:           false,
		},
		{
			name:           "both empty is invalid (misconfigured question)",
			userAnswers:    []int{},
			correctAnswers: []int{},
			want:           false,
		},
		{
			name:           "single correct answer",
			userAnswers:    []int{2},
			correctAnswers: []int{2},
			want:           true,
		},
		{
			name:           "single wrong answer",
			userAnswers:    []int{1},
			correctAnswers: []int{2},
			want:           false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := ValidateMultipleChoice(tt.userAnswers, tt.correctAnswers); got != tt.want {
				t.Errorf("ValidateMultipleChoice(%v, %v) = %v, want %v",
					tt.userAnswers, tt.correctAnswers, got, tt.want)
			}
		})
	}
}

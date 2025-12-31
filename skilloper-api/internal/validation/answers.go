package validation

// ValidateMultipleChoice checks if user's selected answers match correct answers exactly.
// Returns true only if all correct answers are selected and no incorrect answers are selected.
func ValidateMultipleChoice(userAnswers, correctAnswers []int) bool {
	if len(userAnswers) != len(correctAnswers) {
		return false
	}

	// Create sets for comparison
	userSet := make(map[int]bool)
	for _, a := range userAnswers {
		userSet[a] = true
	}

	for _, a := range correctAnswers {
		if !userSet[a] {
			return false
		}
	}

	return true
}

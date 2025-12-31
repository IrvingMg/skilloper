package models

// ValidateAnswerRequest contains the user's answer to validate
type ValidateAnswerRequest struct {
	UserAnswer  *int  `json:"user_answer,omitempty"`  // For single_choice
	UserAnswers []int `json:"user_answers,omitempty"` // For multiple_choice
}

// ValidateAnswerResponse contains the validation result
type ValidateAnswerResponse struct {
	IsCorrect      bool  `json:"is_correct"`
	CorrectAnswer  *int  `json:"correct_answer,omitempty"`  // For single_choice
	CorrectAnswers []int `json:"correct_answers,omitempty"` // For multiple_choice
}

package models

type CreateAnswerRequest struct {
	QuestionID  uint  `json:"question_id"`
	UserAnswer  *int  `json:"user_answer,omitempty"`
	UserAnswers []int `json:"user_answers,omitempty"`
}

type AnswerResponse struct {
	IsCorrect      bool  `json:"is_correct"`
	CorrectAnswer  *int  `json:"correct_answer,omitempty"`
	CorrectAnswers []int `json:"correct_answers,omitempty"`
}

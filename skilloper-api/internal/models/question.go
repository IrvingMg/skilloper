package models

type CreateAnswerRequest struct {
	QuestionID  uint  `json:"question_id"`
	UserAnswers []int `json:"user_answers"`
}

type AnswerResponse struct {
	IsCorrect      bool  `json:"is_correct"`
	CorrectAnswers []int `json:"correct_answers"`
}

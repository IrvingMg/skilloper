package models

import (
	"time"
)

type AttemptStatus string

const (
	AttemptStatusInProgress AttemptStatus = "in_progress"
	AttemptStatusCompleted  AttemptStatus = "completed"
	AttemptStatusAbandoned  AttemptStatus = "abandoned"
)

type QuizAttempt struct {
	ID               uint            `json:"id" gorm:"primaryKey"`
	UserID           uint            `json:"user_id" gorm:"not null;index"`
	QuizID           uint            `json:"quiz_id" gorm:"not null;index"`
	QuizTitle        string          `json:"quiz_title" gorm:"not null"`
	QuizType         string          `json:"quiz_type" gorm:"not null"`
	AttemptNumber    int             `json:"attempt_number" gorm:"not null"`
	Status           AttemptStatus   `json:"status" gorm:"not null;default:'in_progress'"`
	Score            int             `json:"score" gorm:"not null;default:0"`
	CorrectCount     int             `json:"correct_count" gorm:"not null;default:0"`
	TotalCount       int             `json:"total_count" gorm:"not null;default:0"`
	DisplayedOptions string          `json:"-" gorm:"type:text"` // JSON map of questionId -> displayed options
	CreatedAt        time.Time       `json:"created_at"`
	CompletedAt      *time.Time      `json:"completed_at"`
	Answers          []AttemptAnswer `json:"answers" gorm:"foreignKey:AttemptID"`
}

type AttemptAnswer struct {
	ID             uint   `json:"id" gorm:"primaryKey"`
	AttemptID      uint   `json:"attempt_id" gorm:"not null;index"`
	QuestionID     uint   `json:"question_id" gorm:"not null"`
	QuestionText   string `json:"question_text" gorm:"not null"`
	QuestionType   string `json:"question_type" gorm:"not null;default:'single_choice'"`
	UserAnswer     *int   `json:"user_answer"`
	UserAnswers    string `json:"user_answers"`
	CorrectAnswer  *int   `json:"correct_answer"`
	CorrectAnswers string `json:"correct_answers"`
	Options        string `json:"options"`
	IsCorrect      bool   `json:"is_correct" gorm:"not null"`
}

type StartAttemptRequest struct {
	QuizID uint `json:"quiz_id"`
}

type UpdateAttemptRequest struct {
	Status  AttemptStatus       `json:"status"`
	Answers []UserAnswerRequest `json:"answers,omitempty"`
}

type UserAnswerRequest struct {
	QuestionID  uint  `json:"question_id"`
	UserAnswer  *int  `json:"user_answer,omitempty"`
	UserAnswers []int `json:"user_answers,omitempty"`
}

type AttemptSummaryResponse struct {
	ID            uint          `json:"id"`
	UserID        uint          `json:"user_id"`
	QuizID        uint          `json:"quiz_id"`
	QuizTitle     string        `json:"quiz_title"`
	QuizType      string        `json:"quiz_type"`
	AttemptNumber int           `json:"attempt_number"`
	Status        AttemptStatus `json:"status"`
	Score         int           `json:"score"`
	CorrectCount  int           `json:"correct_count"`
	TotalCount    int           `json:"total_count"`
	CreatedAt     time.Time     `json:"created_at"`
	CompletedAt   *time.Time    `json:"completed_at,omitempty"`
}

type AttemptResponse struct {
	ID            uint                    `json:"id"`
	UserID        uint                    `json:"user_id"`
	QuizID        uint                    `json:"quiz_id"`
	QuizTitle     string                  `json:"quiz_title"`
	QuizType      string                  `json:"quiz_type"`
	AttemptNumber int                     `json:"attempt_number"`
	Status        AttemptStatus           `json:"status"`
	Score         int                     `json:"score"`
	CorrectCount  int                     `json:"correct_count"`
	TotalCount    int                     `json:"total_count"`
	CreatedAt     time.Time               `json:"created_at"`
	CompletedAt   *time.Time              `json:"completed_at,omitempty"`
	Answers       []AttemptAnswerResponse `json:"answers"`
}

type AttemptAnswerResponse struct {
	ID             uint     `json:"id"`
	QuestionID     uint     `json:"question_id"`
	QuestionText   string   `json:"question_text"`
	QuestionType   string   `json:"question_type"`
	UserAnswer     *int     `json:"user_answer,omitempty"`
	UserAnswers    []int    `json:"user_answers,omitempty"`
	CorrectAnswer  *int     `json:"correct_answer,omitempty"`
	CorrectAnswers []int    `json:"correct_answers,omitempty"`
	Options        []string `json:"options"`
	IsCorrect      bool     `json:"is_correct"`
}

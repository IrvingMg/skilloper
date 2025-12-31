package models

import (
	"time"
)

// Database Models

// AttemptStatus represents the status of a quiz attempt
type AttemptStatus string

const (
	AttemptStatusInProgress AttemptStatus = "in_progress"
	AttemptStatusCompleted  AttemptStatus = "completed"
)

type QuizAttempt struct {
	ID                 uint            `json:"id" gorm:"primaryKey"`
	DeviceID           string          `json:"device_id" gorm:"not null;index"`
	QuestionnaireID    uint            `json:"questionnaire_id" gorm:"not null"`
	QuestionnaireTitle string          `json:"questionnaire_title" gorm:"not null"`
	QuestionnaireType  string          `json:"questionnaire_type" gorm:"not null"`
	AttemptNumber      int             `json:"attempt_number" gorm:"not null"`
	Status             AttemptStatus   `json:"status" gorm:"not null;default:'in_progress'"`
	Score              int             `json:"score" gorm:"not null;default:0"`
	CorrectCount       int             `json:"correct_count" gorm:"not null;default:0"`
	TotalCount         int             `json:"total_count" gorm:"not null;default:0"`
	CreatedAt          time.Time       `json:"created_at"`
	CompletedAt        *time.Time      `json:"completed_at"`
	Answers            []AttemptAnswer `json:"answers" gorm:"foreignKey:AttemptID"`
}

type AttemptAnswer struct {
	ID             uint   `json:"id" gorm:"primaryKey"`
	AttemptID      uint   `json:"attempt_id" gorm:"not null;index"`
	QuestionID     uint   `json:"question_id" gorm:"not null"`
	QuestionText   string `json:"question_text" gorm:"not null"`
	QuestionType   string `json:"question_type" gorm:"not null;default:'single_choice'"`
	UserAnswer     *int   `json:"user_answer"`                       // For single_choice (nullable)
	UserAnswers    string `json:"user_answers"`                      // JSON array for multiple_choice
	CorrectAnswer  *int   `json:"correct_answer"`                    // For single_choice (nullable)
	CorrectAnswers string `json:"correct_answers"`                   // JSON array for multiple_choice
	Options        string `json:"options"`                           // JSON array of options shown
	IsCorrect      bool   `json:"is_correct" gorm:"not null"`
}

// Request DTOs

type StartAttemptRequest struct {
	DeviceID           string `json:"device_id"`
	QuestionnaireID    uint   `json:"questionnaire_id"`
	QuestionnaireTitle string `json:"questionnaire_title"`
	QuestionnaireType  string `json:"questionnaire_type"`
	TotalCount         int    `json:"total_count"`
}

type CompleteAttemptRequest struct {
	Score        int                          `json:"score"`
	CorrectCount int                          `json:"correct_count"`
	TotalCount   int                          `json:"total_count"`
	Answers      []CreateAttemptAnswerRequest `json:"answers"`
}

type CreateAttemptAnswerRequest struct {
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

// Response DTOs

type AttemptSummaryResponse struct {
	ID                 uint          `json:"id"`
	DeviceID           string        `json:"device_id"`
	QuestionnaireID    uint          `json:"questionnaire_id"`
	QuestionnaireTitle string        `json:"questionnaire_title"`
	QuestionnaireType  string        `json:"questionnaire_type"`
	AttemptNumber      int           `json:"attempt_number"`
	Status             AttemptStatus `json:"status"`
	Score              int           `json:"score"`
	CorrectCount       int           `json:"correct_count"`
	TotalCount         int           `json:"total_count"`
	CreatedAt          time.Time     `json:"created_at"`
	CompletedAt        *time.Time    `json:"completed_at,omitempty"`
}

type AttemptResponse struct {
	ID                 uint                    `json:"id"`
	DeviceID           string                  `json:"device_id"`
	QuestionnaireID    uint                    `json:"questionnaire_id"`
	QuestionnaireTitle string                  `json:"questionnaire_title"`
	QuestionnaireType  string                  `json:"questionnaire_type"`
	AttemptNumber      int                     `json:"attempt_number"`
	Status             AttemptStatus           `json:"status"`
	Score              int                     `json:"score"`
	CorrectCount       int                     `json:"correct_count"`
	TotalCount         int                     `json:"total_count"`
	CreatedAt          time.Time               `json:"created_at"`
	CompletedAt        *time.Time              `json:"completed_at,omitempty"`
	Answers            []AttemptAnswerResponse `json:"answers"`
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

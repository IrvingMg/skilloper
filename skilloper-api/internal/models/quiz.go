package models

import (
	"encoding/json"
	"math/rand/v2"
	"time"
)

const (
	QuestionTypeSingleChoice   = "single_choice"
	QuestionTypeMultipleChoice = "multiple_choice"

	QuizTypePractice = "practice"
	QuizTypeExam     = "exam"
)

type Quiz struct {
	ID          uint       `json:"id" gorm:"primaryKey"`
	UserID      uint       `json:"user_id" gorm:"not null;index;constraint:OnDelete:CASCADE"`
	Title       string     `json:"title" gorm:"not null"`
	Description string     `json:"description"`
	Type        string     `json:"type" gorm:"not null;default:'practice'"` // "practice" or "exam"
	MaxOptions  int        `json:"max_options" gorm:"not null;default:4"`   // Maximum options per question
	CreatedAt   time.Time  `json:"created_at"`
	UpdatedAt   time.Time  `json:"updated_at"`
	Questions   []Question `json:"questions" gorm:"foreignKey:QuizID"`
}

type Question struct {
	ID                   uint      `json:"id" gorm:"primaryKey"`
	QuizID               uint      `json:"quiz_id"`
	QuestionType         string    `json:"question_type" gorm:"not null;default:'single_choice'"` // "single_choice", "multiple_choice"
	QuestionText         string    `json:"question" gorm:"not null"`
	AlternativeQuestions string    `json:"alternative_questions"` // JSON array of alternative question texts
	Code                 string    `json:"code"`
	Language             string    `json:"language"`
	Options              string    `json:"options"`             // JSON array stored as string
	AlternativeOptions   string    `json:"alternative_options"` // JSON array of additional options for variety
	CorrectAnswer        int       `json:"correct_answer"`      // Index in the original options array (for single_choice)
	CorrectAnswers       string    `json:"correct_answers"`     // JSON array of indices (for multiple_choice)
	AlternativeAnswers   string    `json:"alternative_answers"` // JSON array of alternative correct answer texts
	Explanation          string    `json:"explanation"`         // Explanation for the correct answer
	CreatedAt            time.Time `json:"created_at"`
	UpdatedAt            time.Time `json:"updated_at"`
}

// ApplyAlternativeAnswers modifies options in place, replacing the correct answer
// option text with a randomly selected alternative (including the original).
// Returns the modified options slice.
func (q *Question) ApplyAlternativeAnswers(options []string, correctAnswers []int) []string {
	if len(options) == 0 || q.AlternativeAnswers == "" {
		return options
	}

	var alternatives []string
	if err := json.Unmarshal([]byte(q.AlternativeAnswers), &alternatives); err != nil || len(alternatives) == 0 {
		return options
	}

	// Determine the correct answer index to apply alternatives to
	var correctIdx int
	if q.QuestionType == QuestionTypeMultipleChoice {
		if len(correctAnswers) > 0 {
			correctIdx = correctAnswers[0]
		} else {
			return options
		}
	} else {
		correctIdx = q.CorrectAnswer
	}

	if correctIdx < 0 || correctIdx >= len(options) {
		return options
	}

	// Randomly select from original + alternatives
	allTexts := make([]string, 0, 1+len(alternatives))
	allTexts = append(allTexts, options[correctIdx])
	allTexts = append(allTexts, alternatives...)
	options[correctIdx] = allTexts[rand.IntN(len(allTexts))]

	return options
}

type CreateQuizRequest struct {
	Title       string            `json:"title"`
	Description string            `json:"description"`
	Type        string            `json:"type"`                  // "practice" or "exam"
	MaxOptions  int               `json:"max_options,omitempty"` // Optional, defaults to 4 if 0
	Questions   []QuestionRequest `json:"questions"`
}

type QuestionRequest struct {
	QuestionType         string   `json:"question_type,omitempty"` // "single_choice", "multiple_choice"
	Question             string   `json:"question"`
	AlternativeQuestions []string `json:"alternative_questions,omitempty"` // Alternative question texts
	Code                 string   `json:"code,omitempty"`
	Language             string   `json:"language,omitempty"`
	Options              []string `json:"options,omitempty"`
	AlternativeOptions   []string `json:"alternative_options,omitempty"` // Additional options for variety
	CorrectAnswer        int      `json:"correct_answer"`                // For single_choice (0-indexed)
	CorrectAnswers       []int    `json:"correct_answers,omitempty"`     // For multiple_choice (0-indexed)
	AlternativeAnswers   []string `json:"alternative_answers,omitempty"` // Alternative correct answer texts
	Explanation          string   `json:"explanation,omitempty"`
}

type QuizSummary struct {
	ID            uint      `json:"id"`
	Title         string    `json:"title"`
	Description   string    `json:"description"`
	Type          string    `json:"type"`
	MaxOptions    int       `json:"max_options"`
	CreatedAt     time.Time `json:"created_at"`
	UpdatedAt     time.Time `json:"updated_at"`
	QuestionCount int       `json:"question_count"`
}

// questionResponseBase contains shared fields for question responses (unexported, for embedding only)
type questionResponseBase struct {
	ID           uint     `json:"id"`
	QuestionType string   `json:"question_type"`
	Question     string   `json:"question"`
	Code         string   `json:"code,omitempty"`
	Language     string   `json:"language,omitempty"`
	Options      []string `json:"options,omitempty"`
	Explanation  string   `json:"explanation,omitempty"`
}

// QuestionResponse is the response DTO for questions (answers hidden for quiz play)
type QuestionResponse struct {
	questionResponseBase
	CorrectAnswer  int   `json:"-"` // Hidden from client - server validates answers
	CorrectAnswers []int `json:"-"` // Hidden from client - server validates answers
}

// QuestionResponseWithAnswers includes correct answers (for edit mode)
type QuestionResponseWithAnswers struct {
	questionResponseBase
	CorrectAnswer        int      `json:"correct_answer"`                      // 0-indexed
	CorrectAnswers       []int    `json:"correct_answers,omitempty"`           // 0-indexed
	AlternativeQuestions []string `json:"alternative_questions,omitempty"`     // Alternative question texts
	AlternativeOptions   []string `json:"alternative_options,omitempty"`       // Additional distractor options
	AlternativeAnswers   []string `json:"alternative_answers,omitempty"`       // Alternative correct answer texts
}

// quizResponseBase contains shared fields for quiz responses (unexported, for embedding only)
type quizResponseBase struct {
	ID          uint      `json:"id"`
	Title       string    `json:"title"`
	Description string    `json:"description"`
	Type        string    `json:"type"`
	MaxOptions  int       `json:"max_options"`
	CreatedAt   time.Time `json:"created_at"`
	UpdatedAt   time.Time `json:"updated_at"`
}

// QuizResponse is the response DTO for quizzes (answers hidden)
type QuizResponse struct {
	quizResponseBase
	Questions []QuestionResponse `json:"questions"`
}

// QuizResponseWithAnswers includes correct answers (for edit mode)
type QuizResponseWithAnswers struct {
	quizResponseBase
	Questions []QuestionResponseWithAnswers `json:"questions"`
}

// Health check response
type HealthResponse struct {
	Status    string `json:"status"`
	Message   string `json:"message"`
	Timestamp string `json:"timestamp"`
}

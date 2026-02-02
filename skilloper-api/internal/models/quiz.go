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
	ID           uint       `json:"id" gorm:"primaryKey"`
	UserID       uint       `json:"user_id" gorm:"not null;index;constraint:OnDelete:CASCADE"`
	CollectionID *uint      `json:"collection_id,omitempty" gorm:"index;constraint:OnDelete:SET NULL"`
	Title        string     `json:"title" gorm:"not null"`
	Description  string     `json:"description"`
	Type         string     `json:"type" gorm:"not null;default:'practice'"` // "practice" or "exam"
	MaxOptions   int        `json:"max_options" gorm:"not null;default:4"`   // Maximum options per question
	CreatedAt    time.Time  `json:"created_at"`
	UpdatedAt    time.Time  `json:"updated_at"`
	Questions    []Question `json:"questions" gorm:"foreignKey:QuizID"`
}

type Question struct {
	ID                   uint      `json:"id" gorm:"primaryKey"`
	QuizID               uint      `json:"quiz_id"`
	QuestionType         string    `json:"question_type" gorm:"not null;default:'single_choice'"`
	QuestionText         string    `json:"question" gorm:"not null"`
	AlternativeQuestions string    `json:"alternative_questions"`
	Code                 string    `json:"code"`
	Language             string    `json:"language"`
	Options              string    `json:"options"`
	ExtraOptions         string    `json:"extra_options"`
	CorrectAnswers       string    `json:"correct_answers"` // JSON []int
	OptionVariants       string    `json:"option_variants"`
	Explanation          string    `json:"explanation"`
	CreatedAt            time.Time `json:"created_at"`
	UpdatedAt            time.Time `json:"updated_at"`
}

// ApplyOptionVariants randomly replaces each option with one of its variants.
func (q *Question) ApplyOptionVariants(options []string) []string {
	if len(options) == 0 || q.OptionVariants == "" {
		return options
	}

	var variants [][]string
	if err := json.Unmarshal([]byte(q.OptionVariants), &variants); err != nil || len(variants) == 0 {
		return options
	}

	for i := range options {
		if i >= len(variants) || len(variants[i]) == 0 {
			continue
		}
		allTexts := make([]string, 0, 1+len(variants[i]))
		allTexts = append(allTexts, options[i])
		allTexts = append(allTexts, variants[i]...)
		options[i] = allTexts[rand.IntN(len(allTexts))]
	}

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
	QuestionType         string     `json:"question_type,omitempty"`
	Question             string     `json:"question"`
	AlternativeQuestions []string   `json:"alternative_questions,omitempty"`
	Code                 string     `json:"code,omitempty"`
	Language             string     `json:"language,omitempty"`
	Options              []string   `json:"options,omitempty"`
	ExtraOptions         []string   `json:"extra_options,omitempty"`
	CorrectAnswers       []int      `json:"correct_answers"`
	OptionVariants       [][]string `json:"option_variants,omitempty"`
	Explanation          string     `json:"explanation,omitempty"`
}

type QuizSummary struct {
	ID                  uint                   `json:"id"`
	Title               string                 `json:"title"`
	Description         string                 `json:"description"`
	Type                string                 `json:"type"`
	MaxOptions          int                    `json:"max_options"`
	CreatedAt           time.Time              `json:"created_at"`
	UpdatedAt           time.Time              `json:"updated_at"`
	QuestionCount       int                    `json:"question_count"`
	CollectionID        *uint                  `json:"collection_id,omitempty"`
	CollectionName      *string                `json:"collection_name,omitempty"`
	CollectionAncestors []CollectionBreadcrumb `json:"collection_ancestors,omitempty"`
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
	CorrectAnswers []int `json:"-"` // Hidden from client - server validates answers
}

// QuestionResponseWithAnswers includes correct answers (for edit mode)
type QuestionResponseWithAnswers struct {
	questionResponseBase
	CorrectAnswers       []int      `json:"correct_answers"`
	AlternativeQuestions []string   `json:"alternative_questions,omitempty"`
	ExtraOptions         []string   `json:"extra_options,omitempty"`
	OptionVariants       [][]string `json:"option_variants,omitempty"`
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

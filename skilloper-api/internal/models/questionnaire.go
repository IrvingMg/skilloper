package models

import (
	"time"
)

// Database Models - Question types
const (
	QuestionTypeSingleChoice   = "single_choice"
	QuestionTypeMultipleChoice = "multiple_choice"
)

// Note: Limit constants (MinOptionsLimit, MaxOptionsLimit, etc.) are in limits.go

type Questionnaire struct {
	ID          uint       `json:"id" gorm:"primaryKey"`
	Title       string     `json:"title" gorm:"not null"`
	Description string     `json:"description"`
	Type        string     `json:"type" gorm:"not null;default:'practice'"` // "practice" or "exam"
	MaxOptions  int        `json:"max_options" gorm:"not null;default:4"`    // Maximum options per question
	CreatedAt   time.Time  `json:"created_at"`
	UpdatedAt   time.Time  `json:"updated_at"`
	Questions   []Question `json:"questions" gorm:"foreignKey:QuestionnaireID"`
}

type Question struct {
	ID                   uint      `json:"id" gorm:"primaryKey"`
	QuestionnaireID      uint      `json:"questionnaire_id"`
	QuestionType         string    `json:"question_type" gorm:"not null;default:'single_choice'"` // "single_choice", "multiple_choice"
	QuestionText         string    `json:"question" gorm:"not null"`
	AlternativeQuestions string    `json:"alternative_questions"` // JSON array of alternative question texts
	Code                 string    `json:"code"`
	Language             string    `json:"language"`
	Options              string    `json:"options"`             // JSON array stored as string
	AlternativeOptions   string    `json:"alternative_options"` // JSON array of additional options for variety
	CorrectAnswer        int       `json:"correctAnswer"`       // Index in the original options array (for single_choice)
	CorrectAnswers       string    `json:"correct_answers"`     // JSON array of indices (for multiple_choice)
	AlternativeAnswers   string    `json:"alternative_answers"` // JSON array of alternative correct answer texts
	Explanation          string    `json:"explanation"`         // Explanation for the correct answer
	CreatedAt            time.Time `json:"created_at"`
	UpdatedAt            time.Time `json:"updated_at"`
}

// Request DTOs
type CreateQuestionnaireRequest struct {
	Title       string            `json:"title"`
	Description string            `json:"description"`
	Type        string            `json:"type"` // "practice" or "exam"
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
	CorrectAnswer        int      `json:"correctAnswer,omitempty"`       // For single_choice (1-indexed: 1, 2, 3, 4)
	CorrectAnswers       []int    `json:"correct_answers,omitempty"`     // For multiple_choice (1-indexed: [1, 3, 4])
	AlternativeAnswers   []string `json:"alternative_answers,omitempty"` // Alternative correct answer texts
	Explanation          string   `json:"explanation,omitempty"`
}

// Response DTOs
type QuestionnaireSummary struct {
	ID             uint      `json:"id"`
	Title          string    `json:"title"`
	Description    string    `json:"description"`
	Type           string    `json:"type"`
	MaxOptions     int       `json:"max_options"`
	CreatedAt      time.Time `json:"created_at"`
	UpdatedAt      time.Time `json:"updated_at"`
	QuestionCount  int       `json:"question_count"`
}

type QuestionnaireResponse struct {
	ID          uint               `json:"id"`
	Title       string             `json:"title"`
	Description string             `json:"description"`
	Type        string             `json:"type"`
	MaxOptions  int                `json:"max_options"`
	CreatedAt   time.Time          `json:"created_at"`
	UpdatedAt   time.Time          `json:"updated_at"`
	Questions   []QuestionResponse `json:"questions"`
}

type QuestionResponse struct {
	ID             uint     `json:"id"`
	QuestionType   string   `json:"question_type"`
	Question       string   `json:"question"`
	Code           string   `json:"code,omitempty"`
	Language       string   `json:"language,omitempty"`
	Options        []string `json:"options,omitempty"`
	CorrectAnswer  int      `json:"-"` // Hidden from client - server validates answers
	CorrectAnswers []int    `json:"-"` // Hidden from client - server validates answers
	Explanation    string   `json:"explanation,omitempty"`
}

// Health check response
type HealthResponse struct {
	Status    string `json:"status"`
	Message   string `json:"message"`
	Timestamp string `json:"timestamp"`
}

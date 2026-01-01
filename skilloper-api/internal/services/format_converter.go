package services

import (
	"bytes"
	"encoding/json"
	"fmt"
	"path/filepath"
	"strings"

	"github.com/irvingmg/skilloper/skilloper-api/internal/models"
)

// JSONParser implements QuestionnaireParser for user-friendly JSON format
// Features: 1-based indexing, answer as string array, auto-detects question type
type JSONParser struct{}

// NewJSONParser creates a new JSON parser
func NewJSONParser() *JSONParser {
	return &JSONParser{}
}

// FormatName returns the format name
func (p *JSONParser) FormatName() string {
	return "json"
}

// CanParse checks if data is a JSON file by extension and validates content looks like JSON
// This prevents non-JSON content in .json files from being processed
func (p *JSONParser) CanParse(data []byte, filename string) bool {
	ext := strings.ToLower(filepath.Ext(filename))
	if ext != ".json" {
		return false
	}

	// Basic content validation: JSON should start with { or [ after trimming whitespace
	trimmed := bytes.TrimSpace(data)
	if len(trimmed) == 0 {
		return false
	}
	return trimmed[0] == '{' || trimmed[0] == '['
}

// Parse converts JSON to internal format
// Checks the "format" field to determine parsing strategy:
// - "internal": parse directly as CreateQuestionnaireRequest (0-based, correctAnswer)
// - "simple" or omitted: parse as user-friendly format (1-based, answer array)
func (p *JSONParser) Parse(data []byte, _ ParserMetadata) (*models.CreateQuestionnaireRequest, error) {
	// Probe for format field
	var probe struct {
		Format string `json:"format"`
	}
	if err := json.Unmarshal(data, &probe); err != nil {
		return nil, fmt.Errorf("invalid JSON: %w", err)
	}

	// If internal format, parse directly to CreateQuestionnaireRequest
	if probe.Format == models.FormatInternal {
		var req models.CreateQuestionnaireRequest
		if err := json.Unmarshal(data, &req); err != nil {
			return nil, fmt.Errorf("invalid internal format JSON: %w", err)
		}
		return &req, nil
	}

	// Default: parse as user-friendly simplified format
	var simplified models.SimplifiedQuestionnaire
	if err := json.Unmarshal(data, &simplified); err != nil {
		return nil, fmt.Errorf("invalid JSON: %w", err)
	}

	return p.convertToInternal(&simplified)
}

// convertToInternal converts SimplifiedQuestionnaire to CreateQuestionnaireRequest
func (p *JSONParser) convertToInternal(simplified *models.SimplifiedQuestionnaire) (*models.CreateQuestionnaireRequest, error) {
	if simplified == nil {
		return nil, fmt.Errorf("questionnaire is nil")
	}

	if simplified.Title == "" {
		return nil, fmt.Errorf("title is required")
	}

	if len(simplified.Questions) == 0 {
		return nil, fmt.Errorf("at least one question is required")
	}

	// Set defaults
	quizType := simplified.Type
	if quizType == "" {
		quizType = "practice"
	}
	if quizType != "practice" && quizType != "exam" {
		return nil, fmt.Errorf("type must be 'practice' or 'exam', got '%s'", quizType)
	}

	questions := make([]models.QuestionRequest, 0, len(simplified.Questions))

	for i, sq := range simplified.Questions {
		question, err := p.convertQuestion(&sq)
		if err != nil {
			return nil, fmt.Errorf("question %d: %w", i+1, err)
		}
		questions = append(questions, *question)
	}

	return &models.CreateQuestionnaireRequest{
		Title:       simplified.Title,
		Description: simplified.Description,
		Type:        quizType,
		MaxOptions:  simplified.MaxOptions,
		Questions:   questions,
	}, nil
}

// convertQuestion converts a single SimplifiedQuestion to QuestionRequest
func (p *JSONParser) convertQuestion(sq *models.SimplifiedQuestion) (*models.QuestionRequest, error) {
	if sq.Question == "" {
		return nil, fmt.Errorf("question text is required")
	}

	if len(sq.Options) < 2 {
		return nil, fmt.Errorf("at least 2 options are required, got %d", len(sq.Options))
	}

	if len(sq.Options) > models.MaxOptionsLimit {
		return nil, fmt.Errorf("maximum %d options allowed, got %d", models.MaxOptionsLimit, len(sq.Options))
	}

	// Parse answer field to determine type and get 0-based indices
	parsed, err := sq.ParseAnswer()
	if err != nil {
		return nil, err
	}

	question := &models.QuestionRequest{
		Question:             sq.Question,
		AlternativeQuestions: sq.AlternativeQuestions,
		Options:              sq.Options,
		AlternativeOptions:   sq.AlternativeOptions,
		QuestionType:         parsed.QuestionType,
		AlternativeAnswers:   sq.AlternativeAnswers,
		Explanation:          sq.Explanation,
		Code:                 sq.Code,
		Language:             sq.Language,
	}

	// Set answer based on question type (already 0-based from ParseAnswer)
	if parsed.QuestionType == models.QuestionTypeSingleChoice {
		question.CorrectAnswer = parsed.CorrectAnswer
	} else {
		question.CorrectAnswers = parsed.CorrectAnswers
	}

	return question, nil
}

// Backward compatibility aliases
type SimpleJSONParser = JSONParser
type SimplifiedJSONParser = JSONParser

func NewSimpleJSONParser() *JSONParser      { return NewJSONParser() }
func NewSimplifiedJSONParser() *JSONParser  { return NewJSONParser() }

// FormatConverter provides backward-compatible conversion functions
// Deprecated: Use ParserRegistry instead
type FormatConverter struct{}

// NewFormatConverter creates a new format converter
func NewFormatConverter() *FormatConverter {
	return &FormatConverter{}
}

// ParseAndConvertJSON detects format and converts to internal request
// Deprecated: Use ParserRegistry.Parse instead
func (fc *FormatConverter) ParseAndConvertJSON(data []byte) (*models.CreateQuestionnaireRequest, string, error) {
	registry := NewParserRegistry()
	return registry.Parse(data, ParserMetadata{Filename: "file.json"})
}

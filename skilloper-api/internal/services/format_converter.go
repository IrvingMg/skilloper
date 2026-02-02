package services

import (
	"bytes"
	"encoding/json"
	"fmt"
	"path/filepath"
	"strings"

	"github.com/irvingmg/skilloper/skilloper-api/internal/models"
)

type JSONParser struct{}

func NewJSONParser() *JSONParser {
	return &JSONParser{}
}

func (p *JSONParser) FormatName() string {
	return models.FormatJSON
}

func (p *JSONParser) CanParse(data []byte, filename string) bool {
	ext := strings.ToLower(filepath.Ext(filename))
	if ext != ".json" {
		return false
	}

	trimmed := bytes.TrimSpace(data)
	if len(trimmed) == 0 {
		return false
	}
	return trimmed[0] == '{' || trimmed[0] == '['
}

func (p *JSONParser) Parse(data []byte, _ ParserMetadata) (*models.CreateQuizRequest, error) {
	var probe struct {
		Format string `json:"format"`
	}
	if err := json.Unmarshal(data, &probe); err != nil {
		return nil, fmt.Errorf("invalid JSON: %w", err)
	}

	if probe.Format == models.FormatInternal {
		var req models.CreateQuizRequest
		if err := json.Unmarshal(data, &req); err != nil {
			return nil, fmt.Errorf("invalid internal format JSON: %w", err)
		}
		return &req, nil
	}

	var simplified models.SimplifiedQuiz
	if err := json.Unmarshal(data, &simplified); err != nil {
		return nil, fmt.Errorf("invalid JSON: %w", err)
	}

	return p.convertToInternal(&simplified)
}

func (p *JSONParser) convertToInternal(simplified *models.SimplifiedQuiz) (*models.CreateQuizRequest, error) {
	if simplified == nil {
		return nil, fmt.Errorf("quiz is nil")
	}

	if simplified.Title == "" {
		return nil, fmt.Errorf("title is required")
	}

	if len(simplified.Questions) == 0 {
		return nil, fmt.Errorf("at least one question is required")
	}

	quizType := simplified.Type
	if quizType == "" {
		quizType = models.QuizTypePractice
	}
	if quizType != models.QuizTypePractice && quizType != models.QuizTypeExam {
		return nil, fmt.Errorf("type must be '%s' or '%s', got '%s'", models.QuizTypePractice, models.QuizTypeExam, quizType)
	}

	questions := make([]models.QuestionRequest, 0, len(simplified.Questions))

	for i, sq := range simplified.Questions {
		question, err := p.convertQuestion(&sq)
		if err != nil {
			return nil, fmt.Errorf("question %d: %w", i+1, err)
		}
		questions = append(questions, *question)
	}

	return &models.CreateQuizRequest{
		Title:       simplified.Title,
		Description: simplified.Description,
		Type:        quizType,
		MaxOptions:  simplified.MaxOptions,
		Questions:   questions,
	}, nil
}

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

	parsed, err := sq.ParseAnswer()
	if err != nil {
		return nil, err
	}

	return &models.QuestionRequest{
		Question:             sq.Question,
		AlternativeQuestions: sq.AlternativeQuestions,
		Options:              sq.Options,
		ExtraOptions:         sq.ExtraOptions,
		QuestionType:         parsed.QuestionType,
		CorrectAnswers:       parsed.CorrectAnswers,
		OptionVariants:       sq.OptionVariants,
		Explanation:          sq.Explanation,
		Code:                 sq.Code,
		Language:             sq.Language,
	}, nil
}

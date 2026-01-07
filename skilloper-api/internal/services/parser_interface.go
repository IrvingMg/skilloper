package services

import (
	"fmt"

	"github.com/irvingmg/skilloper/skilloper-api/internal/models"
)

type ParserMetadata struct {
	Title       string
	Description string
	Type        string
	MaxOptions  int
	Filename    string
}

type QuizParser interface {
	Parse(data []byte, metadata ParserMetadata) (*models.CreateQuizRequest, error)
	CanParse(data []byte, filename string) bool
	FormatName() string
}

type ParserRegistry struct {
	parsers []QuizParser
}

func NewParserRegistry() *ParserRegistry {
	return &ParserRegistry{
		parsers: []QuizParser{
			NewCSVParserAdapter(),
			NewJSONParser(),
		},
	}
}

func (r *ParserRegistry) Parse(data []byte, metadata ParserMetadata) (*models.CreateQuizRequest, string, error) {
	for _, parser := range r.parsers {
		if parser.CanParse(data, metadata.Filename) {
			req, err := parser.Parse(data, metadata)
			return req, parser.FormatName(), err
		}
	}
	return nil, "", fmt.Errorf("unsupported file format")
}

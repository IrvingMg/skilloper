package services

import (
	"fmt"
	"sync"

	"github.com/irvingmg/skilloper/skilloper-api/internal/models"
)

// ParserMetadata holds optional metadata for parsing (used by CSV, etc.)
type ParserMetadata struct {
	Title       string
	Description string
	Type        string // "practice" or "exam"
	MaxOptions  int
	Filename    string
}

// QuestionnaireParser defines the interface for parsing different quiz formats
type QuestionnaireParser interface {
	// Parse converts raw data to internal CreateQuestionnaireRequest format
	Parse(data []byte, metadata ParserMetadata) (*models.CreateQuestionnaireRequest, error)

	// CanParse checks if this parser can handle the given data/filename
	CanParse(data []byte, filename string) bool

	// FormatName returns the name of this format (for logging/errors)
	FormatName() string
}

// ParserRegistry holds registered parsers and selects appropriate one
type ParserRegistry struct {
	parsers []QuestionnaireParser
}

// Singleton instance for parser registry
var (
	defaultRegistry     *ParserRegistry
	defaultRegistryOnce sync.Once
)

// NewParserRegistry returns the singleton parser registry instance
// Order matters: CSV first (by extension), then JSON parser for all JSON files
func NewParserRegistry() *ParserRegistry {
	defaultRegistryOnce.Do(func() {
		defaultRegistry = &ParserRegistry{
			parsers: []QuestionnaireParser{
				NewCSVParserAdapter(), // Check CSV by file extension first
				NewJSONParser(),       // User-friendly JSON format (1-based, answer array)
			},
		}
	})
	return defaultRegistry
}

// Parse attempts to parse data using registered parsers
func (r *ParserRegistry) Parse(data []byte, metadata ParserMetadata) (*models.CreateQuestionnaireRequest, string, error) {
	for _, parser := range r.parsers {
		if parser.CanParse(data, metadata.Filename) {
			req, err := parser.Parse(data, metadata)
			return req, parser.FormatName(), err
		}
	}
	return nil, "", fmt.Errorf("unsupported file format")
}

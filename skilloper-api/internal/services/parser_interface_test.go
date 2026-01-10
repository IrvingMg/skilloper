package services

import (
	"errors"
	"testing"

	"github.com/irvingmg/skilloper/skilloper-api/internal/models"
)

var errTestParse = errors.New("parse error")

type mockParser struct {
	canParse   bool
	formatName string
	parseErr   error
}

func (m *mockParser) Parse(data []byte, metadata ParserMetadata) (*models.CreateQuizRequest, error) {
	if m.parseErr != nil {
		return nil, m.parseErr
	}
	return &models.CreateQuizRequest{
		Title:       metadata.Title,
		Description: metadata.Description,
		Type:        metadata.Type,
	}, nil
}

func (m *mockParser) CanParse(data []byte, filename string) bool {
	return m.canParse
}

func (m *mockParser) FormatName() string {
	return m.formatName
}

func TestParserRegistry_Parse_SelectsFirstMatchingParser(t *testing.T) {
	registry := &ParserRegistry{
		parsers: []QuizParser{
			&mockParser{canParse: false, formatName: "first"},
			&mockParser{canParse: true, formatName: "second"},
			&mockParser{canParse: true, formatName: "third"},
		},
	}

	metadata := ParserMetadata{Title: "Test", Description: "Desc", Type: "practice"}
	req, format, err := registry.Parse([]byte("data"), metadata)

	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if format != "second" {
		t.Errorf("format = %q, want %q", format, "second")
	}
	if req.Title != "Test" {
		t.Errorf("Title = %q, want %q", req.Title, "Test")
	}
}

func TestParserRegistry_Parse_ReturnsErrorWhenNoParserMatches(t *testing.T) {
	registry := &ParserRegistry{
		parsers: []QuizParser{
			&mockParser{canParse: false, formatName: "first"},
			&mockParser{canParse: false, formatName: "second"},
		},
	}

	_, format, err := registry.Parse([]byte("data"), ParserMetadata{})

	if err == nil {
		t.Fatal("expected error for unsupported format")
	}
	if err.Error() != "unsupported file format" {
		t.Errorf("error = %q, want %q", err.Error(), "unsupported file format")
	}
	if format != "" {
		t.Errorf("format = %q, want empty string", format)
	}
}

func TestParserRegistry_Parse_PropagatesParserError(t *testing.T) {
	registry := &ParserRegistry{
		parsers: []QuizParser{
			&mockParser{canParse: true, formatName: "json", parseErr: errTestParse},
		},
	}

	_, format, err := registry.Parse([]byte("data"), ParserMetadata{})

	if err != errTestParse {
		t.Errorf("error = %v, want errTestParse", err)
	}
	if format != "json" {
		t.Errorf("format = %q, want %q", format, "json")
	}
}

func TestParserRegistry_Parse_EmptyRegistry(t *testing.T) {
	registry := &ParserRegistry{parsers: []QuizParser{}}

	_, _, err := registry.Parse([]byte("data"), ParserMetadata{})

	if err == nil {
		t.Fatal("expected error for empty registry")
	}
}

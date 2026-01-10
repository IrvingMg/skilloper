package jsonutil

import (
	"encoding/json"
	"strings"
	"testing"
)

func TestParseJSONError_SyntaxError(t *testing.T) {
	// Create content with a syntax error on line 3
	content := `{
  "title": "Test",
  "invalid": missing_quotes
}`

	// Try to parse it to get a syntax error
	var data map[string]any
	err := json.Unmarshal([]byte(content), &data)
	if err == nil {
		t.Fatal("Expected JSON parsing to fail")
	}

	info := ParseJSONError(err, []byte(content), "test.json")

	if !info.HasLocation {
		t.Error("Expected HasLocation to be true for syntax error")
	}
	if info.Line != 3 {
		t.Errorf("Line = %d, want 3", info.Line)
	}
	if !strings.Contains(info.Message, "line 3") {
		t.Errorf("Message should mention line 3, got: %s", info.Message)
	}
	if !strings.Contains(info.Message, "test.json") {
		t.Errorf("Message should mention filename, got: %s", info.Message)
	}
}

func TestParseJSONError_FirstLineSyntaxError(t *testing.T) {
	content := `{invalid}`

	var data map[string]any
	err := json.Unmarshal([]byte(content), &data)
	if err == nil {
		t.Fatal("Expected JSON parsing to fail")
	}

	info := ParseJSONError(err, []byte(content), "broken.json")

	if !info.HasLocation {
		t.Error("Expected HasLocation to be true")
	}
	if info.Line != 1 {
		t.Errorf("Line = %d, want 1", info.Line)
	}
}

func TestParseJSONError_LastLineSyntaxError(t *testing.T) {
	content := `{
  "title": "Test"
  "missing_comma": true
}`

	var data map[string]any
	err := json.Unmarshal([]byte(content), &data)
	if err == nil {
		t.Fatal("Expected JSON parsing to fail")
	}

	info := ParseJSONError(err, []byte(content), "test.json")

	if !info.HasLocation {
		t.Error("Expected HasLocation to be true")
	}
	// The error is on line 3 where the missing comma should be
	if info.Line < 1 {
		t.Errorf("Line should be >= 1, got %d", info.Line)
	}
}

func TestParseJSONError_NonSyntaxError(t *testing.T) {
	// Generic error that's not a json.SyntaxError
	err := json.Unmarshal([]byte("null"), new(int))
	if err == nil {
		t.Skip("Skipping - no error produced")
	}

	info := ParseJSONError(err, []byte("null"), "data.json")

	// Should still produce a message but without line/column info
	if info.HasLocation {
		// Some JSON errors may still provide location
		t.Log("Non-syntax error still has location info")
	}
	if info.Message == "" {
		t.Error("Message should not be empty")
	}
	if !strings.Contains(info.Message, "data.json") {
		t.Errorf("Message should mention filename, got: %s", info.Message)
	}
}

func TestParseJSONError_MultilineContent(t *testing.T) {
	// Test with content that has many lines
	content := `{
  "line2": true,
  "line3": true,
  "line4": true,
  "line5": true,
  "line6": broken
}`

	var data map[string]any
	err := json.Unmarshal([]byte(content), &data)
	if err == nil {
		t.Fatal("Expected JSON parsing to fail")
	}

	info := ParseJSONError(err, []byte(content), "multi.json")

	if !info.HasLocation {
		t.Error("Expected HasLocation to be true")
	}
	// Error should be on line 6 or 7 where 'broken' is
	if info.Line < 6 {
		t.Errorf("Line = %d, expected 6 or higher", info.Line)
	}
}

func TestParseJSONError_ColumnInfo(t *testing.T) {
	// Content with error at specific column
	content := `{"key": @invalid}`

	var data map[string]any
	err := json.Unmarshal([]byte(content), &data)
	if err == nil {
		t.Fatal("Expected JSON parsing to fail")
	}

	info := ParseJSONError(err, []byte(content), "test.json")

	if !info.HasLocation {
		t.Error("Expected HasLocation to be true")
	}
	if info.Column < 1 {
		t.Errorf("Column = %d, expected >= 1", info.Column)
	}
	if !strings.Contains(info.Message, "column") {
		t.Errorf("Message should mention column, got: %s", info.Message)
	}
}

func TestParseJSONError_EmptyContent(t *testing.T) {
	content := ``

	var data map[string]any
	err := json.Unmarshal([]byte(content), &data)
	if err == nil {
		t.Fatal("Expected JSON parsing to fail on empty content")
	}

	info := ParseJSONError(err, []byte(content), "empty.json")

	if info.Message == "" {
		t.Error("Message should not be empty")
	}
}

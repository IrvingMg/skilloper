package services

import "testing"

func TestEscapeLikePattern(t *testing.T) {
	tests := []struct {
		name  string
		input string
		want  string
	}{
		{"no special chars", "hello", "hello"},
		{"percent sign", "100%", "100\\%"},
		{"underscore", "test_value", "test\\_value"},
		{"both special chars", "100%_test", "100\\%\\_test"},
		{"multiple percents", "%%", "\\%\\%"},
		{"multiple underscores", "__init__", "\\_\\_init\\_\\_"},
		{"mixed with normal", "a%b_c%d", "a\\%b\\_c\\%d"},
		{"empty string", "", ""},
		{"only special chars", "%_", "\\%\\_"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := escapeLikePattern(tt.input); got != tt.want {
				t.Errorf("escapeLikePattern(%q) = %q, want %q", tt.input, got, tt.want)
			}
		})
	}
}

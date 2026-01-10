package models

import "testing"

func TestSimplifiedQuiz_IsInternalFormat(t *testing.T) {
	tests := []struct {
		name   string
		format string
		want   bool
	}{
		{"internal format", FormatInternal, true},
		{"simple format", FormatSimple, false},
		{"empty format", "", false},
		{"unknown format", "unknown", false},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			sq := &SimplifiedQuiz{Format: tt.format}
			if got := sq.IsInternalFormat(); got != tt.want {
				t.Errorf("IsInternalFormat() = %v, want %v", got, tt.want)
			}
		})
	}
}

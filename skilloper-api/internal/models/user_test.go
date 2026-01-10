package models

import (
	"strings"
	"testing"
)

func TestValidateUsername(t *testing.T) {
	tests := []struct {
		name     string
		username string
		want     bool
	}{
		{"valid alphanumeric", "user123", true},
		{"valid with underscore", "user_123", true},
		{"valid min length", "abcdef", true},
		{"valid max length", strings.Repeat("a", 30), true},
		{"too short", "abc", false},
		{"empty", "", false},
		{"too long", strings.Repeat("a", 31), false},
		{"contains space", "user name", false},
		{"contains @", "user@name", false},
		{"contains dash", "user-name", false},
		{"contains dot", "user.name", false},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := ValidateUsername(tt.username); got != tt.want {
				t.Errorf("ValidateUsername(%q) = %v, want %v", tt.username, got, tt.want)
			}
		})
	}
}

func TestValidatePassword(t *testing.T) {
	tests := []struct {
		name     string
		password string
		want     bool
	}{
		{"valid password", "Password1", true},
		{"valid min length with strength", "Abcdefg1", true},
		{"valid max length", strings.Repeat("A", 35) + strings.Repeat("a", 35) + "12", true},
		{"too short", "Pass1", false},
		{"empty", "", false},
		{"too long", strings.Repeat("A", 40) + strings.Repeat("a", 30) + "123", false},
		{"no uppercase", "password1", false},
		{"no lowercase", "PASSWORD1", false},
		{"no digit", "Password", false},
		{"only digits", "12345678", false},
		{"only lowercase", "abcdefgh", false},
		{"only uppercase", "ABCDEFGH", false},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := ValidatePassword(tt.password); got != tt.want {
				t.Errorf("ValidatePassword(%q) = %v, want %v", tt.password, got, tt.want)
			}
		})
	}
}

func TestValidatePasswordStrength(t *testing.T) {
	tests := []struct {
		name     string
		password string
		want     bool
	}{
		{"has all requirements", "Password1", true},
		{"uppercase lowercase digit", "ABCabc123", true},
		{"single of each", "Aa1", true},
		{"missing uppercase", "password1", false},
		{"missing lowercase", "PASSWORD1", false},
		{"missing digit", "Password", false},
		{"empty", "", false},
		{"only special chars", "!@#$%^&*", false},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := ValidatePasswordStrength(tt.password); got != tt.want {
				t.Errorf("ValidatePasswordStrength(%q) = %v, want %v", tt.password, got, tt.want)
			}
		})
	}
}

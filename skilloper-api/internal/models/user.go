package models

import (
	"regexp"
	"strings"
	"time"
	"unicode"
)

type User struct {
	ID                  uint       `json:"id" gorm:"primaryKey"`
	Username            string     `json:"username" gorm:"uniqueIndex;not null;size:30"`
	PasswordHash        string     `json:"-" gorm:"not null"`
	IsAdmin             bool       `json:"is_admin" gorm:"default:false"`
	FailedAttempts      int        `json:"-" gorm:"default:0"`
	LockedUntil         *time.Time `json:"-"`
	TokensInvalidatedAt *time.Time `json:"-" gorm:"index"`
	CreatedAt           time.Time  `json:"created_at"`
	UpdatedAt           time.Time  `json:"updated_at"`
}

// TokenBlacklist stores invalidated tokens for logout
type TokenBlacklist struct {
	ID        uint      `gorm:"primaryKey"`
	TokenHash string    `gorm:"uniqueIndex;not null;size:64"`
	ExpiresAt time.Time `gorm:"index;not null"`
	CreatedAt time.Time
}

type RegisterRequest struct {
	Username string `json:"username" binding:"required"`
	Password string `json:"password" binding:"required"`
}

type LoginRequest struct {
	Username string `json:"username" binding:"required"`
	Password string `json:"password" binding:"required"`
}

type UserResponse struct {
	ID        uint      `json:"id"`
	Username  string    `json:"username"`
	IsAdmin   bool      `json:"is_admin"`
	CreatedAt time.Time `json:"created_at"`
}

type LoginResponse struct {
	Token string       `json:"token"`
	User  UserResponse `json:"user"`
}

const (
	MinUsernameLength = 6
	MaxUsernameLength = 30
	MinPasswordLength = 8
	MaxPasswordLength = 72

	// Account lockout settings
	MaxFailedAttempts = 5
	LockoutDuration   = 15 * time.Minute

	// Password hashing
	BcryptCost = 12
)

// UsernameRegex validates username format: alphanumeric and underscore only
var UsernameRegex = regexp.MustCompile(`^[a-zA-Z0-9_]+$`)

// NormalizeUsername returns lowercase username
func NormalizeUsername(username string) string {
	return strings.ToLower(username)
}

// ValidateUsername checks if username meets requirements
func ValidateUsername(username string) bool {
	if len(username) < MinUsernameLength || len(username) > MaxUsernameLength {
		return false
	}
	return UsernameRegex.MatchString(username)
}

// ValidatePassword checks if password meets length and strength requirements
func ValidatePassword(password string) bool {
	if len(password) < MinPasswordLength || len(password) > MaxPasswordLength {
		return false
	}
	return ValidatePasswordStrength(password)
}

// ValidatePasswordStrength checks if password has uppercase, lowercase, and digit
func ValidatePasswordStrength(password string) bool {
	var hasUpper, hasLower, hasDigit bool
	for _, char := range password {
		switch {
		case unicode.IsUpper(char):
			hasUpper = true
		case unicode.IsLower(char):
			hasLower = true
		case unicode.IsDigit(char):
			hasDigit = true
		}
	}
	return hasUpper && hasLower && hasDigit
}

type UpdatePasswordRequest struct {
	CurrentPassword string `json:"current_password" binding:"required"`
	NewPassword     string `json:"new_password" binding:"required"`
}

type PasswordConfirmRequest struct {
	Password string `json:"password" binding:"required"`
}

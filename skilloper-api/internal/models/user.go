package models

import (
	"regexp"
	"time"
)

type User struct {
	ID                uint       `json:"id" gorm:"primaryKey"`
	Username          string     `json:"username" gorm:"uniqueIndex;not null;size:30"`
	PasswordHash      string     `json:"-" gorm:"not null"`
	FailedAttempts    int        `json:"-" gorm:"default:0"`
	LockedUntil       *time.Time `json:"-"`
	CreatedAt         time.Time  `json:"created_at"`
	UpdatedAt         time.Time  `json:"updated_at"`
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
)

// UsernameRegex validates username format: alphanumeric and underscore only
var UsernameRegex = regexp.MustCompile(`^[a-zA-Z0-9_]+$`)

package models

import (
	"time"
)

// RefreshToken stores refresh tokens for session management with token rotation
type RefreshToken struct {
	ID        uint       `gorm:"primaryKey"`
	TokenHash string     `gorm:"uniqueIndex;not null;size:64"` // SHA256 hash
	UserID    uint       `gorm:"index;not null"`
	FamilyID  string     `gorm:"index:idx_family_revoked;not null;size:36"` // UUID for rotation tracking
	ExpiresAt time.Time  `gorm:"index;not null"`
	Revoked   bool       `gorm:"index:idx_family_revoked;default:false"` // Composite index for token reuse detection
	RevokedAt *time.Time `gorm:"index"`
	CreatedAt time.Time
}

// RefreshTokenRequest is the request body for token refresh
type RefreshTokenRequest struct {
	RefreshToken string `json:"refresh_token" binding:"required"`
}

// TokenPairResponse is returned when tokens are refreshed
type TokenPairResponse struct {
	AccessToken  string `json:"access_token"`
	RefreshToken string `json:"refresh_token"`
	ExpiresIn    int    `json:"expires_in"` // Seconds until access token expires
}

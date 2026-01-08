package services

import (
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"strings"
	"time"
	"unicode"

	"github.com/golang-jwt/jwt/v5"
	"go.uber.org/zap"
	"golang.org/x/crypto/bcrypt"
	"gorm.io/gorm"

	apperrors "github.com/irvingmg/skilloper/skilloper-api/internal/errors"
	"github.com/irvingmg/skilloper/skilloper-api/internal/models"
)

const bcryptCost = 12

var (
	// Dummy hash for timing attack prevention (hash of empty string)
	dummyHash, _ = bcrypt.GenerateFromPassword([]byte(""), bcryptCost)
)

type Claims struct {
	UserID   uint   `json:"user_id"`
	Username string `json:"username"`
	jwt.RegisteredClaims
}

type AuthService struct {
	db        *gorm.DB
	jwtSecret []byte
	jwtExpiry time.Duration
	logger    *zap.Logger
}

func NewAuthService(db *gorm.DB, jwtSecret string, jwtExpiry time.Duration, logger *zap.Logger) *AuthService {
	return &AuthService{
		db:        db,
		jwtSecret: []byte(jwtSecret),
		jwtExpiry: jwtExpiry,
		logger:    logger,
	}
}

func (s *AuthService) Register(req models.RegisterRequest) (*models.LoginResponse, error) {
	if err := s.validateUsername(req.Username); err != nil {
		s.logger.Warn("Registration failed: invalid username",
			zap.String("username", req.Username),
			zap.String("reason", "validation_failed"))
		return nil, err
	}
	if err := s.validatePassword(req.Password); err != nil {
		s.logger.Warn("Registration failed: invalid password",
			zap.String("username", req.Username),
			zap.String("reason", "password_validation_failed"))
		return nil, err
	}

	normalizedUsername := strings.ToLower(req.Username)

	var existingUser models.User
	result := s.db.Where("username = ?", normalizedUsername).First(&existingUser)
	if result.Error == nil {
		s.logger.Warn("Registration failed: username taken",
			zap.String("username", normalizedUsername))
		return nil, apperrors.ErrUsernameTaken
	}
	if !errors.Is(result.Error, gorm.ErrRecordNotFound) {
		return nil, apperrors.NewDatabaseError("USER_LOOKUP_FAILED", "Failed to check username", result.Error)
	}

	hashedPassword, err := bcrypt.GenerateFromPassword([]byte(req.Password), bcryptCost)
	if err != nil {
		return nil, apperrors.NewInternalError("PASSWORD_HASH_FAILED", "Failed to hash password", err)
	}

	user := models.User{
		Username:     normalizedUsername,
		PasswordHash: string(hashedPassword),
	}

	if err := s.db.Create(&user).Error; err != nil {
		// Handle unique constraint violation (race condition)
		if strings.Contains(err.Error(), "UNIQUE constraint failed") ||
			strings.Contains(err.Error(), "duplicate key") {
			return nil, apperrors.ErrUsernameTaken
		}
		return nil, apperrors.NewDatabaseError("USER_CREATE_FAILED", "Failed to create user", err)
	}

	s.logger.Info("User registered successfully",
		zap.Uint("user_id", user.ID),
		zap.String("username", user.Username))

	token, err := s.generateToken(user)
	if err != nil {
		return nil, err
	}

	return &models.LoginResponse{
		Token: token,
		User: models.UserResponse{
			ID:        user.ID,
			Username:  user.Username,
			CreatedAt: user.CreatedAt,
		},
	}, nil
}

func (s *AuthService) Login(req models.LoginRequest) (*models.LoginResponse, error) {
	normalizedUsername := strings.ToLower(req.Username)

	var user models.User
	result := s.db.Where("username = ?", normalizedUsername).First(&user)

	// Check if account is locked
	if result.Error == nil && user.LockedUntil != nil && time.Now().Before(*user.LockedUntil) {
		s.logger.Warn("Login attempt on locked account",
			zap.String("username", normalizedUsername),
			zap.Time("locked_until", *user.LockedUntil))
		return nil, apperrors.ErrAccountLocked
	}

	// Always perform password comparison to prevent timing attacks
	hashToCompare := dummyHash
	if result.Error == nil {
		hashToCompare = []byte(user.PasswordHash)
	}

	if err := bcrypt.CompareHashAndPassword(hashToCompare, []byte(req.Password)); err != nil || result.Error != nil {
		// Log failed attempt
		if result.Error != nil && !errors.Is(result.Error, gorm.ErrRecordNotFound) {
			return nil, apperrors.NewDatabaseError("USER_LOOKUP_FAILED", "Failed to lookup user", result.Error)
		}

		// Track failed attempts for existing users
		if result.Error == nil {
			s.recordFailedAttempt(&user)
		}

		s.logger.Warn("Login failed: invalid credentials",
			zap.String("username", normalizedUsername),
			zap.Bool("user_exists", result.Error == nil))

		return nil, apperrors.ErrInvalidCredentials
	}

	// Reset failed attempts on successful login
	if user.FailedAttempts > 0 || user.LockedUntil != nil {
		s.db.Model(&user).Updates(map[string]any{
			"failed_attempts": 0,
			"locked_until":    nil,
		})
	}

	token, err := s.generateToken(user)
	if err != nil {
		return nil, err
	}

	s.logger.Info("User logged in successfully",
		zap.Uint("user_id", user.ID),
		zap.String("username", user.Username))

	return &models.LoginResponse{
		Token: token,
		User: models.UserResponse{
			ID:        user.ID,
			Username:  user.Username,
			CreatedAt: user.CreatedAt,
		},
	}, nil
}

func (s *AuthService) recordFailedAttempt(user *models.User) {
	user.FailedAttempts++

	updates := map[string]any{
		"failed_attempts": user.FailedAttempts,
	}

	if user.FailedAttempts >= models.MaxFailedAttempts {
		lockUntil := time.Now().Add(models.LockoutDuration)
		updates["locked_until"] = lockUntil
		s.logger.Warn("Account locked due to too many failed attempts",
			zap.Uint("user_id", user.ID),
			zap.String("username", user.Username),
			zap.Int("failed_attempts", user.FailedAttempts),
			zap.Time("locked_until", lockUntil))
	}

	s.db.Model(user).Updates(updates)
}

func (s *AuthService) ValidateToken(tokenString string) (*Claims, error) {
	// Check if token is blacklisted
	if s.isTokenBlacklisted(tokenString) {
		return nil, apperrors.ErrInvalidToken
	}

	token, err := jwt.ParseWithClaims(tokenString, &Claims{}, func(token *jwt.Token) (any, error) {
		if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, apperrors.ErrInvalidToken
		}
		return s.jwtSecret, nil
	})

	if err != nil {
		return nil, apperrors.ErrInvalidToken
	}

	claims, ok := token.Claims.(*Claims)
	if !ok || !token.Valid {
		return nil, apperrors.ErrInvalidToken
	}

	return claims, nil
}

func (s *AuthService) BlacklistToken(tokenString string, expiresAt time.Time) error {
	hash := s.hashToken(tokenString)

	blacklist := models.TokenBlacklist{
		TokenHash: hash,
		ExpiresAt: expiresAt,
	}

	// Ignore duplicate key errors (token already blacklisted)
	if err := s.db.Create(&blacklist).Error; err != nil {
		if !strings.Contains(err.Error(), "UNIQUE constraint failed") {
			return err
		}
	}

	return nil
}

func (s *AuthService) isTokenBlacklisted(tokenString string) bool {
	hash := s.hashToken(tokenString)

	var blacklist models.TokenBlacklist
	result := s.db.Where("token_hash = ? AND expires_at > ?", hash, time.Now()).First(&blacklist)
	return result.Error == nil
}

func (s *AuthService) hashToken(token string) string {
	hash := sha256.Sum256([]byte(token))
	return hex.EncodeToString(hash[:])
}

// CleanupExpiredBlacklist removes expired entries from the blacklist
func (s *AuthService) CleanupExpiredBlacklist() error {
	return s.db.Where("expires_at < ?", time.Now()).Delete(&models.TokenBlacklist{}).Error
}

func (s *AuthService) GetUserByID(id uint) (*models.UserResponse, error) {
	var user models.User
	result := s.db.First(&user, id)
	if errors.Is(result.Error, gorm.ErrRecordNotFound) {
		return nil, apperrors.NewNotFoundError("USER_NOT_FOUND", "User not found")
	}
	if result.Error != nil {
		return nil, apperrors.NewDatabaseError("USER_LOOKUP_FAILED", "Failed to lookup user", result.Error)
	}

	return &models.UserResponse{
		ID:        user.ID,
		Username:  user.Username,
		CreatedAt: user.CreatedAt,
	}, nil
}

func (s *AuthService) generateToken(user models.User) (string, error) {
	now := time.Now()
	claims := Claims{
		UserID:   user.ID,
		Username: user.Username,
		RegisteredClaims: jwt.RegisteredClaims{
			ExpiresAt: jwt.NewNumericDate(now.Add(s.jwtExpiry)),
			IssuedAt:  jwt.NewNumericDate(now),
			NotBefore: jwt.NewNumericDate(now),
			Subject:   user.Username,
		},
	}

	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	tokenString, err := token.SignedString(s.jwtSecret)
	if err != nil {
		return "", apperrors.NewInternalError("TOKEN_GENERATION_FAILED", "Failed to generate token", err)
	}

	return tokenString, nil
}

func (s *AuthService) GetTokenExpiry(tokenString string) (time.Time, error) {
	token, err := jwt.ParseWithClaims(tokenString, &Claims{}, func(token *jwt.Token) (any, error) {
		return s.jwtSecret, nil
	})

	if err != nil {
		return time.Time{}, err
	}

	claims, ok := token.Claims.(*Claims)
	if !ok {
		return time.Time{}, errors.New("invalid claims")
	}

	return claims.ExpiresAt.Time, nil
}

func (s *AuthService) validateUsername(username string) error {
	if len(username) < models.MinUsernameLength || len(username) > models.MaxUsernameLength {
		return apperrors.ErrInvalidUsername
	}
	if !models.UsernameRegex.MatchString(username) {
		return apperrors.ErrInvalidUsername
	}
	return nil
}

func (s *AuthService) validatePassword(password string) error {
	if len(password) < models.MinPasswordLength || len(password) > models.MaxPasswordLength {
		return apperrors.ErrInvalidPassword
	}

	// Check password complexity
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

	if !hasUpper || !hasLower || !hasDigit {
		return apperrors.ErrWeakPassword
	}

	return nil
}
